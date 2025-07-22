local STATE = require "tsmsms.constants.state"
local UBUS_RESPONSE_STATUS = require "tsmsms.constants.ubus_response_status"
local pdu_decoder = require "tsmsms.pdu_decoder"
local util = require "luci.util"
local uloop = require "uloop"


local state_machine = {
    state = STATE.WAIT,
    timeout_timer = uloop.timer(function () end),
    sms_index = nil,
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

function state_machine.send_error()
    if state_machine.def_req then
        state_machine.app.conn:reply(state_machine.def_req, { status = UBUS_RESPONSE_STATUS.ERROR })
        state_machine.app.conn:complete_deferred_request(state_machine.def_req, 0)
        state_machine.def_req = nil
    end
    state_machine.state = STATE.WAIT
end

function state_machine.start_get_count_of_received_sms(req)
    if state_machine.busy_check(req) then return end

    state_machine.app.conn:reply(req, { status = UBUS_RESPONSE_STATUS.STARTED })
    state_machine.def_req = state_machine.app.conn:defer_request(req)

    state_machine.state = STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CMGF_OK
    util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=1" })
    state_machine.start_timeout_timer()
end

function state_machine.get_count_of_received_sms_CMGF_OK_handler()
    state_machine.state = STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CPMS_RESULT
    util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CPMS?" })
end

function state_machine.get_count_of_received_sms_CPMS_RESULT_handler(at_response)
    if state_machine.timeout_timer then state_machine.timeout_timer:cancel() end
    local sms_count = at_response:match('"SM",(%d+)')
    state_machine.app.conn:reply(state_machine.def_req, { status = UBUS_RESPONSE_STATUS.OK, result = sms_count })

    state_machine.app.conn:complete_deferred_request(state_machine.def_req, 0)
    state_machine.def_req = nil
    state_machine.state = STATE.WAIT
end

function state_machine.get_count_of_received_sms_event_handler(at_response)
    if state_machine.state == STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CMGF_OK then
        if at_response:find("^AT%+CMGF") and at_response:find("OK") then
            state_machine.get_count_of_received_sms_CMGF_OK_handler()
        else
            state_machine.send_error()
        end
    elseif state_machine.state == STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CPMS_RESULT then
        if at_response:find("^AT%+CPMS") and at_response:find("OK") then
            state_machine.get_count_of_received_sms_CPMS_RESULT_handler(at_response)
        else
            state_machine.send_error()
        end
    end
end

function state_machine.start_read_sms_by_index(req, sms_index)
    if state_machine.busy_check(req) then return end

    state_machine.app.conn:reply(req, { status = UBUS_RESPONSE_STATUS.STARTED })
    state_machine.def_req = state_machine.app.conn:defer_request(req)
    state_machine.sms_index = sms_index

    state_machine.state = STATE.READ_SMS_BY_INDEX.WAITING_CMGF_OK
    util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=0" })
end

function state_machine.read_sms_by_index_CMGF_OK_handler()
    state_machine.state = STATE.READ_SMS_BY_INDEX.WAITING_CMGR_RESULT
    util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGR="..tostring(state_machine.sms_index) })
end

function state_machine.read_sms_by_index_CMGR_RESULT_handler(at_response)
    if state_machine.timeout_timer then state_machine.timeout_timer:cancel() end

    local pdu_data = ""
    local shift = 2

    if at_response:find("OK") then
        shift = 8
    end

    for i = #at_response - shift, 1, -1 do
        if at_response:sub(i, i) == '\n' then break end
        pdu_data = at_response:sub(i, i) .. pdu_data
    end

    local parsed_sms = pdu_decoder.parse(pdu_data)

    state_machine.app.conn:reply(state_machine.def_req, {
        status = UBUS_RESPONSE_STATUS.OK,
        sender = parsed_sms.sender_number,
        date = parsed_sms.date.text,
        message = parsed_sms.message_text,
    })

    state_machine.app.conn:complete_deferred_request(state_machine.def_req, 0)
    state_machine.def_req = nil
    state_machine.state = STATE.WAIT
end

function state_machine.read_sms_by_index_event_handler(at_response)
    if state_machine.state == STATE.READ_SMS_BY_INDEX.WAITING_CMGF_OK then
        if at_response:find("^AT%+CMGF") and at_response:find("OK") then
            state_machine.read_sms_by_index_CMGF_OK_handler()
        else
            state_machine.send_error()
        end
    elseif state_machine.state == STATE.READ_SMS_BY_INDEX.WAITING_CMGR_RESULT then
        if at_response:find("\r\n+CMGR", 1, true) then
            state_machine.read_sms_by_index_CMGR_RESULT_handler(at_response)
        end
    end
end

function state_machine.event_handler(at_response)
    if state_machine.state == STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CMGF_OK or state_machine.state == STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CPMS_RESULT then
        state_machine.get_count_of_received_sms_event_handler(at_response)
    elseif state_machine.state == STATE.READ_SMS_BY_INDEX.WAITING_CMGF_OK or state_machine.state == STATE.READ_SMS_BY_INDEX.WAITING_CMGR_RESULT then
        state_machine.read_sms_by_index_event_handler(at_response)
    end
end

function state_machine.sms_received_event_handler(at_response)
    if state_machine.state == STATE.WAIT then
        state_machine.app.conn:notify(state_machine.app.ubus_methods["tsmodem.sms"].__ubusobj, 'new-sms-received', {
            status = UBUS_RESPONSE_STATUS.OK,
            result = at_response,
        })
    else
        state_machine.event_handler(at_response)
    end
end

return state_machine