local STATE = require "tsmsms.constants.state"
local UBUS_RESPONSE_STATUS = require "tsmsms.constants.ubus_response_status"
local CMS_ERROR = require "tsmsms.constants.cms_error"
local pdu_decoder = require "tsmsms.pdu_decoder"
local util = require "luci.util"
local uloop = require "uloop"

local delete_sms_by_index = require "tsmsms.state_machine.delete_sms_by_index"
local get_count_of_received_sms = require "tsmsms.state_machine.get_count_of_received_sms"
local read_all_sms = require "tsmsms.state_machine.read_all_sms"
local read_sms_by_index = require "tsmsms.state_machine.read_sms_by_index"
local send_sms = require "tsmsms.state_machine.send_sms"

local state_machine = {
    state = STATE.WAIT,
    module_name = "tsmsms",
    timeout_timer = uloop.timer(function () end),
    tsmodem_driver_response_timeout = 60,
    send_sms = { part = 0, chunks = {} },
    send_sms_error_counter = 0,
    read_all_sms_buffer = {},
    sms_index = nil,
    def_req = nil,
    app = nil,
}

function state_machine.init(app)
    state_machine.app = app
    state_machine.tsmodem_driver_response_timeout = app.uci_config.tsmodem_response_timeout

    delete_sms_by_index.extend_state_machine(state_machine)
    get_count_of_received_sms.extend_state_machine(state_machine)
    read_all_sms.extend_state_machine(state_machine)
    read_sms_by_index.extend_state_machine(state_machine)
    send_sms.extend_state_machine(state_machine)
end

function state_machine.on_timeout()
    if_debug("[timeout]", "timeout reached", "")
    if state_machine.timeout_timer then
        state_machine.timeout_timer:cancel()
        state_machine.timeout_timer = nil
    end

    if state_machine.def_req then
        state_machine.app.conn:reply(state_machine.def_req, {
            status = UBUS_RESPONSE_STATUS.TIMEOUT
        })
        state_machine.app.conn:complete_deferred_request(state_machine.def_req, 0)
    end

    if state_machine.state == STATE.SEND_SMS.WAITING_CMGF_OK or state_machine.state == STATE.SEND_SMS.WAITING_CMGS_OK or state_machine.state == STATE.SEND_SMS.WAITING_PDU_TEXT_OK then
        if state_machine.app.uci_config.send_email_if_error then
            if_debug("[send_sms]", "send error via tsmail", "")
            util.ubus("tsmail", "send", {
                to = state_machine.app.uci_config.email_address,
                from = state_machine.app.uci_config.email_sender_address_tsmail,
                subj = string.format("Ошибка при отправке SMS: %s", CMS_ERROR.tsmodem_timeout.title_ru),
                body = string.format("Название ошибки: %s, Описание ошибки: %s", CMS_ERROR.tsmodem_timeout.title_ru, CMS_ERROR.tsmodem_timeout.description_ru),
            })
        end

        if_debug("[send_sms]", "send error to tsmodem.journal", "")
        util.ubus("tsmodem.journal", "send", {
            journal = {
                datetime = os.date("%Y-%m-%d %H:%M:%S"),
                name = "Ошибка при отправке SMS",
                source = "Tsmsms",
                command = "send_sms",
                response = "timeout",
                error_title = CMS_ERROR.tsmodem_timeout.title_ru,
                error_description = CMS_ERROR.tsmodem_timeout.description_ru,
            }
        })
    end

    state_machine.reset_state()
end

function state_machine.start_timeout_timer(timeout)
    local timeout_timer = uloop.timer(state_machine.on_timeout)
    timeout_timer:set(timeout or 3000)
    state_machine.timeout_timer = timeout_timer
end

function state_machine.reset_state()
    state_machine.send_sms = { part = 0, chunks = {} }
    state_machine.send_sms_error_counter = 0
    state_machine.read_all_sms_buffer = {}
    state_machine.sms_index = nil
    state_machine.def_req = nil
    state_machine.state = STATE.WAIT
end

function state_machine.busy_check(req)
    if state_machine.state ~= STATE.WAIT then
        state_machine.app.conn:reply(req, { status = UBUS_RESPONSE_STATUS.BUSY })
        if_debug("[busy_check]", "state machine (current status): BUSY", "")
        return true
    end
    if_debug("[busy_check]", "state machine (current status): WAIT", "")
    return false
end

function state_machine.tsmodem_busy_check(util_ubus_response)
    if util_ubus_response then
        if util_ubus_response["status"] and util_ubus_response["status"] == "busy" then
            if state_machine.def_req then
                state_machine.app.conn:reply(state_machine.def_req, { status = UBUS_RESPONSE_STATUS.TSMODEM_BUSY })
            end
            state_machine.end_reply()
            if_debug("[tsmodem_busy_check]", "tsmodem: ", "busy")
            return true
        else
            if_debug("[tsmodem_busy_check]", "tsmodem: ", "not busy")
            return false
        end
    else
        if state_machine.def_req then
            state_machine.app.conn:reply(state_machine.def_req, { status = UBUS_RESPONSE_STATUS.ERROR })
        end
        state_machine.end_reply()
        if_debug("[tsmodem_busy_check]", "response from tsmodem is 'nil'", "")
        return true
    end
end

function state_machine.tsmodem_send_at(command)
    return util.ubus("tsmodem.driver", "send_at", { ["command"] = command, module_name = state_machine.module_name }, state_machine.tsmodem_driver_response_timeout)
end

function state_machine.tsmodem_unlock()
    return util.ubus("tsmodem.driver", "unlock", { module_name = state_machine.module_name }, state_machine.tsmodem_driver_response_timeout)
end

function state_machine.start_reply(req)
    state_machine.app.conn:reply(req, { status = UBUS_RESPONSE_STATUS.STARTED })
    state_machine.def_req = state_machine.app.conn:defer_request(req)
end

function state_machine.end_reply()
    if state_machine.def_req then
        state_machine.app.conn:complete_deferred_request(state_machine.def_req, 0)
    end

    state_machine.tsmodem_unlock()
    state_machine.reset_state()
end

function state_machine.send_error(message)
    if state_machine.def_req then
        state_machine.app.conn:reply(state_machine.def_req, {
            status = UBUS_RESPONSE_STATUS.ERROR,
            message = message,
        })
        state_machine.end_reply()
    end
    state_machine.state = STATE.WAIT
end

-- general event handlers
function state_machine.event_handler(at_response)
    if state_machine.state == STATE.WAIT then
        if_debug("AT-ANSWER", at_response, "")
    else
        if_debug("[AT-RESPONSE]", at_response, "")
    end

    if state_machine.state == STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CMGF_OK or state_machine.state == STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CPMS_RESULT then
        state_machine.get_count_of_received_sms_event_handler(at_response)
    elseif state_machine.state == STATE.READ_SMS_BY_INDEX.WAITING_CMGF_OK or state_machine.state == STATE.READ_SMS_BY_INDEX.WAITING_CMGR_RESULT then
        state_machine.read_sms_by_index_event_handler(at_response)
    elseif state_machine.state == STATE.SEND_SMS.WAITING_CMGF_OK or state_machine.state == STATE.SEND_SMS.WAITING_CMGS_OK or state_machine.state == STATE.SEND_SMS.WAITING_PDU_TEXT_OK then
        state_machine.send_sms_handler(at_response)
    elseif state_machine.state == STATE.DELETE_SMS_BY_INDEX.WAITING_CMGF_OK or state_machine.state == STATE.DELETE_SMS_BY_INDEX.WAITING_CMGD_OK then
        state_machine.delete_sms_by_index_event_handler(at_response)
    elseif state_machine.state == STATE.READ_ALL_SMS.WAITING_CMGF_OK or state_machine.state == STATE.READ_ALL_SMS.WAITING_CMGL_RESULT then
        state_machine.read_all_sms_handler(at_response)
    end
end

function state_machine.sms_received_event_handler(at_response)
    if state_machine.state == STATE.WAIT then
        if_debug("[NEW-SMS-RECEIVED:AT-RESPONSE]", at_response, "")

        local pdu_data = get_sms_pdu_data_from_at_response(at_response)
        local parsed_sms = pdu_decoder.parse(pdu_data)

        state_machine.app.conn:notify(state_machine.app.ubus_methods["tsmodem.sms"].__ubusobj, 'NEW-SMS-RECEIVED', {
            status = UBUS_RESPONSE_STATUS.OK,
            sender = parsed_sms.sender_number,
            date = parsed_sms.date.text,
            message = parsed_sms.message_text,
        })

        if_debug("[NEW-SMS-RECEIVED:SMS-DATA]", util.serialize_json(parsed_sms), "")
    else
        state_machine.event_handler(at_response)
    end
end

return state_machine
