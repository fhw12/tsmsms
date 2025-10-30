-- Данный файл определяет методы необходимые для запроса "чтение смс по индексу"

local STATE = require "tsmsms.constants.state"
local UBUS_RESPONSE_STATUS = require "tsmsms.constants.ubus_response_status"
local pdu_decoder = require "tsmsms.pdu_decoder"
local util = require "luci.util"

local read_sms_by_index = {}

function read_sms_by_index.extend_state_machine(state_machine)
    -- Вызывается при начале обработки запроса
    function state_machine.start_read_sms_by_index(req, sms_index)
        if_debug("[start_read_sms_by_index]", "ubus request received", "")
        if state_machine.busy_check(req) then return end
        state_machine.start_reply(req)

        state_machine.sms_index = sms_index
        state_machine.state = STATE.READ_SMS_BY_INDEX.WAITING_CMGF_OK
        local util_ubus_response = state_machine.tsmodem_send_at("AT+CMGF=0") -- Включение PDU режима
        if state_machine.tsmodem_busy_check(util_ubus_response) then return end
        state_machine.start_timeout_timer()
        if_debug("[start_read_sms_by_index]", "started", "")
    end

    -- Отправляет запрос на чтение смс по определенному индексу
    function state_machine.read_sms_by_index_CMGF_OK_handler()
        state_machine.state = STATE.READ_SMS_BY_INDEX.WAITING_CMGR_RESULT
        state_machine.tsmodem_send_at("AT+CMGR="..tostring(state_machine.sms_index))
    end

    -- Читает полученную смс и завершает выполнение запроса
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

    -- Обработчик состояний read_sms_by_index
    function state_machine.read_sms_by_index_event_handler(at_response)
        if state_machine.state == STATE.READ_SMS_BY_INDEX.WAITING_CMGF_OK then
            if at_response:find("AT%+CMGF") and not at_response:find("ERROR") then -- PDU режим установлен
                if_debug("[read_sms_by_index]", "CMGF_OK", "")
                state_machine.read_sms_by_index_CMGF_OK_handler()
            else
                if_debug("[read_sms_by_index]", "CMGF_ERROR", "")
                state_machine.send_error()
            end
        elseif state_machine.state == STATE.READ_SMS_BY_INDEX.WAITING_CMGR_RESULT then
            if at_response:find("\r\n+CMGR", 1, true) then -- AT ответ с PDU данными смс получен
                if_debug("[read_sms_by_index]", "CMGR_OK", "")
                state_machine.read_sms_by_index_CMGR_RESULT_handler(at_response)
            elseif at_response:find("%+CMS%sERROR:%s321") then
                if_debug("[read_sms_by_index]", "CMGR_SMS_INDEX_ERROR", "no_such_sms")
                state_machine.send_error("Wrong index, no such sms found")
            end
        end
    end
end

return read_sms_by_index
