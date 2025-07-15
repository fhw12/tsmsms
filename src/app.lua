local signal = require("posix.signal")
signal.signal(signal.SIGINT, function(signum)

  io.write("\n")
  print("-----------------------")
  print("SmsApp debug stopped.")
  print("-----------------------")
  io.write("\n")
  os.exit(128 + signum)
end)

--[[ Характеристика модуля sms

Один раз в 3 секунды модуль проверят содержимое каталога /var/sppon/tsmsms/outgoing
Если есть файлы с текстом смс, то берётся первый файл (самый старый по дате)
и запускается пошаговый процесс отправки.

Шаг 1: Перевести модем в режим PDU
Шаг 2: Указать модему длину смс-сообшения (согласно pdu)
Шаг 3: Отправить смс
Шаг 4: Перевести модем в режим TEXT

Если на каком-то шаге модем вернул ошибку, 
то прервать выполнение остльных шагов и венуть ошибку в Веб-UI (если смс отправлена из веб-консоли)
либо вернуть ошибку по Email (если смс отправлена в ответ на sms-команду).
Записать ошибку в Журнал событий.

Весь процесс (шаги выше и вывод ошибок) продолжается 5 минут.
Если через 5 минут не получилось отправть смс, то перемещаем данный файл
в каталог /var/sppon/tsmsms/failed

Повторяем всё с начала для следующего файла.

]]
local file = require "tsmsms.file"
local sms = require "tsmsms.sms"
local timer = require "tsmsms.timer"
local ubus = require "ubus"
local util = require "luci.util"
local sys = require "luci.sys"
local uloop = require "uloop"


require "tsmsms.util"


local app = {}
app.conn = nil
app.pipeout_file = "/tmp/wspipeout.fifo"     -- Gwsocket creates it
app.pipein_file = "/tmp/wspipein.fifo"       -- Gwsocket creates it

-- default state (wait ubus request): wait
-- get_count_of_received_sms states: sms_count_waiting_CMGF_OK, sms_count_waiting_CPMS_result
app.state = "wait"

local def_req = nil


function app:init()
  app.conn = ubus.connect()
  if not app.conn then
    error("Failed to connect to ubus from Smsd")
  else
    app:make_ubus()
    app:subscribe_ubus()
  end
end

function app:make_ubus()
  if_debug("APP", app, "")
  local ubus_methods = {
    ["tsmodem.sms"] = {
      send_sms = {
        function(req, msg)
          local resp = {}
          local smsphone = tostring(msg["phone"])
          local smstext = tostring(msg["text"])

          if smsphone and smstext then
            local total_files, folder = app.file:makePduChunks(smsphone, smstext)
            resp = {
              ["total_chunks"] = total_files,
              ["folder"] = tostring(folder)
            }
          else
            resp = {
              ["ERROR"] = "No phone or sms text got via UBUS"
            }
          end
          app.conn:reply(req, resp)
        end, { phone = ubus.STRING, text = ubus.STRING }
      },

      get_count_of_received_sms = {
        function (req, msg)
          if app.state ~= "wait" then
            app.conn.reply(req, { status = "busy" })
          else
            app.conn:reply(req, { status = "started" })
            def_req = app.conn:defer_request(req)

            app.state = "sms_count_waiting_CMGF_OK"
            util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=1" })
          end
        end, { }
      },

      read_sms_by_index = {
        function (req, msg)
          local resp = {}
          app.conn:reply(req, resp)
        end, { index = ubus.INT32 }
      },

      read_all_sms = {
        function (req, msg)
          local resp = {}
          app.conn:reply(req, resp)
        end, { }
      },

      delete_sms_by_index = {
        function (req, msg)
          local resp = {}
          app.conn:reply(req, resp)
        end, { index = ubus.INT32 }
      },
    }
  }
  app.conn:add( ubus_methods )
end

function app:subscribe_ubus()
  local sub = {
    notify = function(msg, name)
      print("==============================")
      print("TSMSMS NOTIFY", util.serialize_json({ module = "tsmsms", result = msg["answer"]}), name)
      if(name == "SMS-SENT-OK") then
        local shell_command = string.format("echo '%s' > %s", util.serialize_json({
          module = "tsmsms",
          AT_answer = msg["answer"]
        }), app.pipein_file)
        if_debug("SMS-SENT-OK", msg["answer"], "")
        sys.process.exec({"/bin/sh", "-c", shell_command }, true, true, false)
      elseif(name == "SMS-SENT-ERROR") then
        local shell_command = string.format("echo '%s' > %s", util.serialize_json({
          module = "tsmsms",
          SMS_send_result = msg["resp"]
        }), app.pipein_file)
        if_debug("SMS-SENT-ERROR", msg["answer"], "")
        sys.process.exec({"/bin/sh", "-c", shell_command }, true, true, false)
      elseif(name == "AT-ANSWER") then
        if_debug("AT-ANSWER", msg["answer"], "")

        if app.state == "sms_count_waiting_CMGF_OK" then
          if msg["answer"]:find("^AT%+CMGF") and msg["answer"]:find("OK") then
            app.state = "sms_count_waiting_CPMS_result"
            util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CPMS?" })
          else
            app.conn:reply(def_req, { status = 'error' })
            app.conn:complete_deferred_request(def_req, 0)
            def_req = nil
            app.state = "wait"
          end
        elseif app.state == "sms_count_waiting_CPMS_result" then
          if msg["answer"]:find("^AT%+CPMS") and msg["answer"]:find("OK") then
            local sms_count = msg["answer"]:match('"SM",(%d+)')
            app.conn:reply(def_req, { status = "ok", result = sms_count })
          else
            app.conn:reply(def_req, { status = 'error' })
          end
          app.conn:complete_deferred_request(def_req, 0)
          def_req = nil
          app.state = "wait"
        end
      end
      print("==============================")
    end
  }
  app.conn:subscribe("tsmodem.driver", sub)
end


-- [[ Initialize ]]
local metatable = {
  __call = function(app, sms, file, timer)
    app.sms = sms
    app.file = file
    app.timer = timer

    uloop.init()
    app:init()
    sms:init(app, file, timer)
    file:init(app, sms, timer)
    timer:init(app, file, sms)

    -- Запускаем периодический опрос на проверку
    -- появился ли новый файл с текстом для отправки по SMS
    timer.general:set(timer.steps["0_GENERAL"])

    uloop.run()
    app.conn:close()

    return app
  end
}
setmetatable(app, metatable)

app(sms, file, timer)
