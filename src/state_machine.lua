local STATE = require "tsmsms.constants.state"
local UBUS_RESPONSE_STATUS = require "constants.ubus_response_status"
local util = require "luci.util"
local uloop = require "uloop"


local state_machine = {
    state = STATE.WAIT,
    timeout_timer = uloop.timer(function () end),
    def_req = nil,
    app = nil,
}

function state_machine.init(app)
    state_machine.app = app
end

function state_machine.on_timeout()
    state_machine.state = STATE.WAIT
    state_machine.timeout_timer = nil
    if state_machine.def_req then
        state_machine.app.conn:reply(state_machine.def_req, {
            status = UBUS_RESPONSE_STATUS.TIMEOUT
        })
        state_machine.app.conn:complete_deferred_request(state_machine.def_req, 0)
        state_machine.def_req = nil
    end
end

function state_machine.start_timeout_timer()
    local timeout_timer = uloop.timer(state_machine.on_timeout)
    timeout_timer:set(3000)
    state_machine.timeout_timer = timeout_timer
end

function state_machine.busy_check(req)
    if state_machine.state ~= STATE.WAIT then
        state_machine.app.conn:reply(req, { status = UBUS_RESPONSE_STATUS.BUSY })
        return true
    end
    return false
end

function state_machine.start_get_count_of_received_sms(req)
    if state_machine.busy_check(req) then return end

    state_machine.app.conn:reply(req, { status = UBUS_RESPONSE_STATUS.STARTED })
    state_machine.def_req = state_machine.app.conn:defer_request(req)

    state_machine.state = STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CMGF_OK
    util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=1" })
end

function state_machine.get_count_of_received_sms_CMGF_OK_handler()
    state_machine.state = STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CPMS_RESULT
    util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CPMS?" })
end

function state_machine.get_count_of_received_sms_CPMS_RESULT_handler()
    if state_machine.timeout_timer then state_machine.timeout_timer:cancel() end
    state_machine.app.conn:reply(state_machine.def_req, { status = UBUS_RESPONSE_STATUS.OK, result = "todo" })
end

function state_machine.get_count_of_received_sms_event_handler(at_response)
    if state_machine.state == STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CMGF_OK then
        state_machine.get_count_of_received_sms_CMGF_OK_handler()
    elseif state_machine.state == STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CPMS_RESULT then
        state_machine.get_count_of_received_sms_CPMS_RESULT_handler()
    end
end

function state_machine.event_handler(at_response)
    if state_machine.state == STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CMGF_OK or state_machine.state == STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CPMS_RESULT then
        state_machine.get_count_of_received_sms_event_handler(at_response)
    end
end

return state_machine