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

local state_machine = require "tsmsms.state_machine"
local file = require "tsmsms.file"
local sms = require "tsmsms.sms"
local ubus = require "ubus"
local util = require "luci.util"
local sys = require "luci.sys"
local uloop = require "uloop"
require "tsmsms.util"


local app = {}

app.conn = nil
app.pipeout_file = "/tmp/wspipeout.fifo"     -- Gwsocket creates it
app.pipein_file = "/tmp/wspipein.fifo"       -- Gwsocket creates it

function app:init()
  app.conn = ubus.connect()
  if not app.conn then
    error("Failed to connect to ubus from Smsd")
  else
    state_machine.init(app)
    app:make_ubus()
    app:subscribe_ubus()
  end
end

function app:make_ubus()
  local ubus_methods = {
    ["tsmodem.sms"] = {
      send_sms = {
        function(req, msg)
          local sms_phone = tostring(msg["phone"])
          local sms_text = tostring(msg["text"])
          state_machine.start_send_sms(req, sms_phone, sms_text)
        end, { phone = ubus.STRING, text = ubus.STRING }
      },

      get_count_of_received_sms = {
        function (req, msg)
          state_machine.start_get_count_of_received_sms(req)
        end, { }
      },

      read_sms_by_index = {
        function (req, msg)
          local sms_index = msg["index"]
          state_machine.start_read_sms_by_index(req, sms_index)
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
  app.conn:add(ubus_methods)
  app.ubus_methods = ubus_methods
end

function app:subscribe_ubus()
  local sub = {
    notify = function(msg, name)
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
        state_machine.event_handler(msg["answer"])
      elseif name == "SMS-RECEIVED" then
        state_machine.sms_received_event_handler(msg["answer"])
      end
    end
  }
  app.conn:subscribe("tsmodem.driver", sub)
end


-- [[ Initialize ]]
local metatable = {
  __call = function(app, sms, file)
    app.sms = sms
    app.file = file

    uloop.init()
    app:init()
    sms:init(app, file)
    file:init(app, sms)

    uloop.run()
    app.conn:close()

    return app
  end
}
setmetatable(app, metatable)

app(sms, file)
