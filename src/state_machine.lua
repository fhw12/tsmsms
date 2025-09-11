local STATE = require "tsmsms.constants.state"
local UBUS_RESPONSE_STATUS = require "tsmsms.constants.ubus_response_status"
local CMS_ERROR = require "tsmsms.constants.cms_error"
local pdu_decoder = require "tsmsms.pdu_decoder"
local sms = require "tsmsms.sms"
local util = require "luci.util"
local uloop = require "uloop"


local state_machine = {
    state = STATE.WAIT,
    module_name = "tsmsms",
    timeout_timer = uloop.timer(function () end),
    tsmodem_driver_response_timeout = 60,
    send_sms = { part = 0, chunks = {} },
    read_all_sms_buffer = {},
    sms_index = nil,
    def_req = nil,
    app = nil,
}

function state_machine.init(app)
    state_machine.app = app
    state_machine.tsmodem_driver_response_timeout = app.uci_config.tsmodem_response_timeout
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

-- get count of received sms
function state_machine.start_get_count_of_received_sms(req)
    if_debug("[get_count_of_received_sms]", "ubus request received", "")
    if state_machine.busy_check(req) then return end
    state_machine.start_reply(req)

    state_machine.state = STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CMGF_OK
    -- local util_ubus_response = util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=1" }, state_machine.tsmodem_driver_response_timeout)
    local util_ubus_response = state_machine.tsmodem_send_at("AT+CMGF=1")
    if state_machine.tsmodem_busy_check(util_ubus_response) then return end
    state_machine.start_timeout_timer()
    if_debug("[get_count_of_received_sms]", "started", "")
end

function state_machine.get_count_of_received_sms_CMGF_OK_handler()
    state_machine.state = STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CPMS_RESULT
    -- util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CPMS?" }, state_machine.tsmodem_driver_response_timeout)
    state_machine.tsmodem_send_at("AT+CPMS?")
end

function state_machine.get_count_of_received_sms_CPMS_RESULT_handler(at_response)
    if state_machine.timeout_timer then state_machine.timeout_timer:cancel() end

    local sms_count = at_response:match('"SM",(%d+)')
    if_debug("[get_count_of_received_sms]", "SMS_COUNT (result)", tostring(sms_count))

    state_machine.app.conn:reply(state_machine.def_req, { status = UBUS_RESPONSE_STATUS.OK, result = sms_count })
    state_machine.end_reply()
end

function state_machine.get_count_of_received_sms_event_handler(at_response)
    if state_machine.state == STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CMGF_OK then
        if at_response:find("AT%+CMGF") and not at_response:find("ERROR") then --and at_response:find("OK") then
            if_debug("[get_count_of_received_sms]", "CMGF_OK", "")
            state_machine.get_count_of_received_sms_CMGF_OK_handler()
        else
            if_debug("[get_count_of_received_sms]", "CMGF_ERROR", "")
            state_machine.send_error()
        end
    elseif state_machine.state == STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CPMS_RESULT then
        if at_response:find("%+CPMS:") and not at_response:find("ERROR") then -- and at_response:find("OK") then
            if_debug("[get_count_of_received_sms]", "CPMS_OK", "")
            state_machine.get_count_of_received_sms_CPMS_RESULT_handler(at_response)
        else
            if at_response:find("%sOK%s") then
                if_debug("[get_count_of_received_sms]", "OK FROM CMGF", "")
            else
                if_debug("[get_count_of_received_sms]", "CPMS_ERROR", "")
                state_machine.send_error()
            end
        end
    end
end

-- read sms by index
function state_machine.start_read_sms_by_index(req, sms_index)
    if_debug("[start_read_sms_by_index]", "ubus request received", "")
    if state_machine.busy_check(req) then return end
    state_machine.start_reply(req)

    state_machine.sms_index = sms_index
    state_machine.state = STATE.READ_SMS_BY_INDEX.WAITING_CMGF_OK
    -- local util_ubus_response = util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=0" }, state_machine.tsmodem_driver_response_timeout)
    local util_ubus_response = state_machine.tsmodem_send_at("AT+CMGF=0")
    if state_machine.tsmodem_busy_check(util_ubus_response) then return end
    state_machine.start_timeout_timer()
    if_debug("[start_read_sms_by_index]", "started", "")
end

function state_machine.read_sms_by_index_CMGF_OK_handler()
    state_machine.state = STATE.READ_SMS_BY_INDEX.WAITING_CMGR_RESULT
    -- util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGR="..tostring(state_machine.sms_index) }, state_machine.tsmodem_driver_response_timeout)
    state_machine.tsmodem_send_at("AT+CMGR="..tostring(state_machine.sms_index))
end

function state_machine.read_sms_by_index_CMGR_RESULT_handler(at_response)
    if state_machine.timeout_timer then state_machine.timeout_timer:cancel() end

    local pdu_data = get_sms_pdu_data_from_at_response(at_response)
    local parsed_sms = pdu_decoder.parse(pdu_data)

    local response = {
        status = UBUS_RESPONSE_STATUS.OK,
        sender = parsed_sms.sender_number,
        date = parsed_sms.date.text,
        message = parsed_sms.message_text,
    }

    state_machine.app.conn:reply(state_machine.def_req, response)
    state_machine.end_reply()

    if_debug("[read_sms_by_index]", util.serialize_json(response), "")
end

function state_machine.read_sms_by_index_event_handler(at_response)
    if state_machine.state == STATE.READ_SMS_BY_INDEX.WAITING_CMGF_OK then
        if at_response:find("AT%+CMGF") and not at_response:find("ERROR") then --and at_response:find("OK") then
            if_debug("[read_sms_by_index]", "CMGF_OK", "")
            state_machine.read_sms_by_index_CMGF_OK_handler()
        else
            if_debug("[read_sms_by_index]", "CMGF_ERROR", "")
            state_machine.send_error()
        end
    elseif state_machine.state == STATE.READ_SMS_BY_INDEX.WAITING_CMGR_RESULT then
        if at_response:find("\r\n+CMGR", 1, true) then
            if_debug("[read_sms_by_index]", "CMGR_OK", "")
            state_machine.read_sms_by_index_CMGR_RESULT_handler(at_response)
        elseif at_response:find("%+CMS%sERROR:%s321") then
            if_debug("[read_sms_by_index]", "CMGR_SMS_INDEX_ERROR", "no_such_sms")
            state_machine.send_error("Wrong index, no such sms found")
        end
    end
end

-- delete sms by index
function state_machine.start_delete_sms_by_index(req, sms_index)
    if_debug("[start_delete_sms_by_index]", "ubus request received", "")
    if state_machine.busy_check(req) then return end
    state_machine.start_reply(req)

    state_machine.sms_index = sms_index
    state_machine.state = STATE.DELETE_SMS_BY_INDEX.WAITING_CMGF_OK
    -- local util_ubus_response = util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=1" }, state_machine.tsmodem_driver_response_timeout)
    local util_ubus_response = state_machine.tsmodem_send_at("AT+CMGF=1")
    if state_machine.tsmodem_busy_check(util_ubus_response) then return end
    state_machine.start_timeout_timer()
    if_debug("[start_delete_sms_by_index]", "started", "")
end

function state_machine.delete_sms_by_index_CMGF_OK_handler()
    state_machine.state = STATE.DELETE_SMS_BY_INDEX.WAITING_CMGD_OK
    -- util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGD="..tostring(state_machine.sms_index) }, state_machine.tsmodem_driver_response_timeout)
    state_machine.tsmodem_send_at("AT+CMGD="..tostring(state_machine.sms_index))
end

function state_machine.delete_sms_by_index_CMGD_OK_handler()
    if state_machine.timeout_timer then state_machine.timeout_timer:cancel() end

    state_machine.app.conn:reply(state_machine.def_req, { status = UBUS_RESPONSE_STATUS.OK })
    state_machine.end_reply()
end

function state_machine.delete_sms_by_index_event_handler(at_response)
    if state_machine.state == STATE.DELETE_SMS_BY_INDEX.WAITING_CMGF_OK then
        if at_response:find("AT%+CMGF") and not at_response:find("ERROR") then --and at_response:find("OK") then
            if_debug("[delete_sms_by_index]", "CMGF_OK", "")
            state_machine.delete_sms_by_index_CMGF_OK_handler()
        elseif at_response:find("%sOK%s") then
            if_debug("[delete_sms_by_index]", "OK", "previous_ok")
        else
            if_debug("[delete_sms_by_index]", "CMGF_ERROR", "")
            state_machine.send_error()
        end
    elseif state_machine.state == STATE.DELETE_SMS_BY_INDEX.WAITING_CMGD_OK then
        if at_response:find("AT%+CMGD") and not at_response:find("ERROR") then --and at_response:find("OK") then
            if_debug("[delete_sms_by_index]", "CMGD_OK", "")
            state_machine.delete_sms_by_index_CMGD_OK_handler()
        end
    end
end

-- read all sms
function state_machine.start_read_all_sms(req)
    if_debug("[read_all_sms]", "ubus request received", "")
    if state_machine.busy_check(req) then return end
    state_machine.start_reply(req)

    state_machine.read_all_sms_buffer = {}
    state_machine.state = STATE.READ_ALL_SMS.WAITING_CMGF_OK
    -- local util_ubus_response = util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=0" }, state_machine.tsmodem_driver_response_timeout)
    local util_ubus_response = state_machine.tsmodem_send_at("AT+CMGF=0")
    if state_machine.tsmodem_busy_check(util_ubus_response) then return end
    state_machine.start_timeout_timer()
    if_debug("[read_all_sms]", "started", "")
end

function state_machine.read_all_sms_CMGF_OK_handler()
    state_machine.state = STATE.READ_ALL_SMS.WAITING_CMGL_RESULT
    -- util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGL=4" }, state_machine.tsmodem_driver_response_timeout)
    state_machine.tsmodem_send_at("AT+CMGL=4")
end

function state_machine.read_all_sms_CMGL_SMS_DATA_handler(at_response)
    state_machine.read_all_sms_buffer[#state_machine.read_all_sms_buffer+1] = at_response
end

function state_machine.read_all_sms_CMGL_OK_handler()
    if state_machine.timeout_timer then state_machine.timeout_timer:cancel() end

    local response = {}

    for i = 1, #state_machine.read_all_sms_buffer do
        local at_response_sms_data = state_machine.read_all_sms_buffer[i]
        local sms_index = at_response_sms_data:match('CMGL:%s*(%d+)')

        local pdu_data = ""
        local pdu_data_length_counter = 0
        for j = #at_response_sms_data, 1, -1 do
            local char = at_response_sms_data:sub(j, j)

            if (string.byte(char) >= string.byte("0") and string.byte(char) <= string.byte("9")) or (string.byte(char) >= string.byte("A") and string.byte(char) <= string.byte("F")) then
                pdu_data = char .. pdu_data
                pdu_data_length_counter = pdu_data_length_counter + 1
            else
                if pdu_data_length_counter > 10 then
                    break
                else
                    pdu_data = ""
                    pdu_data_length_counter = 0
                end
            end
        end

        local parsed_sms = pdu_decoder.parse(pdu_data)

        response[i] = {
            sms_index = sms_index,
            sender = parsed_sms.sender_number,
            date = parsed_sms.date.text,
            message = parsed_sms.message_text,
        }
    end

    state_machine.app.conn:reply(state_machine.def_req, { status = UBUS_RESPONSE_STATUS.OK, result = response })
    state_machine.end_reply()

    if_debug("[read_sms_by_index]", util.serialize_json(response), "")
end

function state_machine.read_all_sms_handler(at_response)
    if state_machine.state == STATE.READ_ALL_SMS.WAITING_CMGF_OK then
        if at_response:find("AT%+CMGF") and not at_response:find("ERROR") then -- at_response:find("OK") then
            if_debug("[read_all_sms]", "CMGF_OK", "")
            state_machine.read_all_sms_CMGF_OK_handler()
        else
            if_debug("[read_all_sms]", "CMGF_ERROR", "")
            state_machine.send_error()
        end
    elseif state_machine.state == STATE.READ_ALL_SMS.WAITING_CMGL_RESULT then
        if at_response:find("%+CMGL:") then
            if_debug("[read_all_sms]", "CMGL_SMS_DATA", "")
            state_machine.read_all_sms_CMGL_SMS_DATA_handler(at_response)
            if at_response:find("OK") then
            if_debug("[read_all_sms]", "CMGL_OK", "")
                state_machine.read_all_sms_CMGL_OK_handler()
            end
        elseif at_response:find("^%s*OK%s*$") then
            if_debug("[read_all_sms]", "CMGL_OK", "")
            state_machine.read_all_sms_CMGL_OK_handler()
        elseif not at_response:find("AT%+CMGL=4") then
            if_debug("[read_all_sms]", "CMGL_ERROR", "")
            state_machine.send_error()
        end
    end
end

-- send sms
function state_machine.start_send_sms(req, sms_phone, sms_text)
    if_debug("[send_sms]", "ubus request received", "")
    if state_machine.busy_check(req) then return end
    local resp = {}

    if sms_phone and sms_text then
        local sms_chunks = sms.makePduChunks(sms_phone, sms_text)

        resp = {
            status = UBUS_RESPONSE_STATUS.OK,
            ["total_chunks"] = #sms_chunks,
        }

        state_machine.state = STATE.SEND_SMS.WAITING_CMGF_OK
        state_machine.send_sms.chunks = sms_chunks
        state_machine.send_sms.part = 1

        -- local util_ubus_response = util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=0" }, state_machine.tsmodem_driver_response_timeout)
        local util_ubus_response = state_machine.tsmodem_send_at("AT+CMGF=0")
        if state_machine.tsmodem_busy_check(util_ubus_response) then return end

        state_machine.start_timeout_timer(30000)
        if_debug("[send_sms]", "started", "")
    else
        resp = {
            status = UBUS_RESPONSE_STATUS.ERROR,
            error = "No phone or sms text got via UBUS",
        }
    end

    state_machine.app.conn:reply(req, resp)
end

function state_machine.send_sms_CMGF_OK_handler()
    local pdu_length = state_machine.send_sms.chunks[state_machine.send_sms.part].pdu_length
    -- util.ubus("tsmodem.driver", "send_at", { ["command"] = string.format("AT+CMGS=%s", pdu_length) }, state_machine.tsmodem_driver_response_timeout)
    state_machine.tsmodem_send_at(string.format("AT+CMGS=%s", pdu_length))
    state_machine.state = STATE.SEND_SMS.WAITING_CMGS_OK
end

function state_machine.send_sms_CMGS_OK_handler()
    local pdu_text = state_machine.send_sms.chunks[state_machine.send_sms.part].pdu_text
    -- util.ubus("tsmodem.driver", "send_at", { ["command"] = string.format("%s\26", pdu_text) }, state_machine.tsmodem_driver_response_timeout)
    state_machine.tsmodem_send_at(string.format("%s\26", pdu_text))
    state_machine.state = STATE.SEND_SMS.WAITING_PDU_TEXT_OK
end

function state_machine.send_sms_PDU_TEXT_OK_handler()
    if state_machine.timeout_timer then state_machine.timeout_timer:cancel() end

    if state_machine.send_sms.part < #state_machine.send_sms.chunks then
        state_machine.send_sms.part = state_machine.send_sms.part + 1
        state_machine.state = STATE.SEND_SMS.WAITING_CMGF_OK
        -- util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=0" }, state_machine.tsmodem_driver_response_timeout)
        state_machine.tsmodem_send_at("AT+CMGF=0")
        state_machine.start_timeout_timer(30000)
        if_debug("[send_sms]", "new part started ["..tostring(state_machine.send_sms.part).."/"..tostring(#state_machine.send_sms.chunks).."]", "")
    else
        -- util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=1" }, state_machine.tsmodem_driver_response_timeout)
        state_machine.tsmodem_unlock()
        state_machine.state = STATE.WAIT
    end
end

function state_machine.send_sms_handler(at_response)
    if at_response:find("%+CMS") and at_response:find("ERROR") then
        if_debug("[send_sms]", "ERROR", at_response)
        local error_msg = at_response:match("(%+CMS ERROR: %d+)")
        local error_number = tonumber(error_msg:match("%d+"))

        local error_table = CMS_ERROR[error_number]
        local error_title = ""
        local error_description = ""

        if error_table then
            error_title = error_table.title_ru
            error_description = error_table.description_ru
        end

        util.ubus("tsmodem.journal", "send", {
            journal = {
                datetime = os.date("%Y-%m-%d %H:%M:%S"),
                name = "Ошибка при отправке SMS",
                source = "Tsmsms",
                command = "send_sms",
                response = error_number,
                error_title = error_title,
                error_description = error_description,
            }
        })
    elseif state_machine.state == STATE.SEND_SMS.WAITING_CMGF_OK then
        if at_response:find("AT%+CMGF") then
            if_debug("[send_sms]", "CMGF_OK", "")
            state_machine.send_sms_CMGF_OK_handler()
        end
    elseif state_machine.state == STATE.SEND_SMS.WAITING_CMGS_OK then
        if at_response:find("^AT%+CMGS") then --and at_response:find(">") then
            if_debug("[send_sms]", "CMGS_OK", "")
            state_machine.send_sms_CMGS_OK_handler()
        end
    elseif state_machine.state == STATE.SEND_SMS.WAITING_PDU_TEXT_OK then
        if at_response:find("%+CMGS") then --and at_response:find("OK") then
            if_debug("[send_sms]", "CMGS_OK (PDU TEXT)", "")
            state_machine.send_sms_PDU_TEXT_OK_handler()
        end
    end
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