local signal = require("posix.signal")
signal.signal(signal.SIGINT, function(signum)
  io.write("\n")
  print("-----------------------")
  print("SmsApp debug stopped.")
  print("-----------------------")
  io.write("\n")
  os.exit(128 + signum)
end)

local TSMODEM_DRIVER_EVENT = require "tsmsms.constants.tsmodem_driver_event"
local state_machine = require "tsmsms.state_machine"
local uci = require "luci.model.uci".cursor()
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
    local send_sms_max_attempts = tonumber(uci:get("tsmsms", "general", "send_sms_max_attempts"))
    local tsmodem_response_timeout = tonumber(uci:get("tsmsms", "general", "tsmodem_response_timeout"))
    local send_email_if_error = (uci:get("tsmsms", "general", "send_email_if_error") == '1')
    local email_address = uci:get("tsmsms", "general", "email_address")

    app.uci_config = {
      send_sms_max_attempts = send_sms_max_attempts,
      tsmodem_response_timeout = tsmodem_response_timeout,
      send_email_if_error = send_email_if_error,
      email_address = email_address,
    }

    if_debug('uci_config', 'send_sms_max_attempts: ', app.uci_config.send_sms_max_attempts)
    if_debug('uci_config', 'tsmodem_response_timeout: ', app.uci_config.tsmodem_response_timeout)
    if_debug('uci_config', 'send_email_if_error: ', app.uci_config.send_email_if_error)
    if_debug('uci_config', 'email_address: ', app.uci_config.email_address)

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
          state_machine.start_read_all_sms(req)
        end, { }
      },

      delete_sms_by_index = {
        function (req, msg)
          local sms_index = msg["index"]
          state_machine.start_delete_sms_by_index(req, sms_index)
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
      if name == TSMODEM_DRIVER_EVENT.SMS_SENT_OK then
        local shell_command = string.format("echo '%s' > %s", util.serialize_json({
          module = "tsmsms",
          AT_answer = msg["answer"]
        }), app.pipein_file)
        if_debug(TSMODEM_DRIVER_EVENT.SMS_SENT_OK, msg["answer"], "")
        sys.process.exec({"/bin/sh", "-c", shell_command }, true, true, false)
      elseif name == TSMODEM_DRIVER_EVENT.SMS_SENT_ERROR then
        local shell_command = string.format("echo '%s' > %s", util.serialize_json({
          module = "tsmsms",
          SMS_send_result = msg["resp"]
        }), app.pipein_file)
        if_debug(TSMODEM_DRIVER_EVENT.SMS_SENT_ERROR, msg["answer"], "")
        print("SMS SENT ERROR", msg["answer"])
        sys.process.exec({"/bin/sh", "-c", shell_command }, true, true, false)
      elseif name == TSMODEM_DRIVER_EVENT.AT_ANSWER then
        state_machine.event_handler(msg["answer"])
      elseif name == TSMODEM_DRIVER_EVENT.SMS_RECEIVED then
        state_machine.sms_received_event_handler(msg["answer"])
      end
    end
  }
  app.conn:subscribe("tsmodem.driver", sub)
end


-- [[ Initialize ]]
local metatable = {
  __call = function(app)
    -- app.file = file

    uloop.init()
    app:init()

    uloop.run()
    app.conn:close()

    return app
  end
}
setmetatable(app, metatable)
app()