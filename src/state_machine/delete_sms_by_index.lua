-- Данный файл определяет методы необходимые для запроса "удаление смс по индексу"

local STATE = require "tsmsms.constants.state"
local UBUS_RESPONSE_STATUS = require "tsmsms.constants.ubus_response_status"

local delete_sms_by_index = {}

function delete_sms_by_index.extend_state_machine(state_machine)
    -- Вызывается при начале обработки запроса
    function state_machine.start_delete_sms_by_index(req, sms_index)
        if_debug("[start_delete_sms_by_index]", "ubus request received", "")
        if state_machine.busy_check(req) then return end
        state_machine.start_reply(req)

        state_machine.sms_index = sms_index
        state_machine.state = STATE.DELETE_SMS_BY_INDEX.WAITING_CMGF_OK
        local util_ubus_response = state_machine.tsmodem_send_at("AT+CMGF=1") -- Включение текстового режима
        if state_machine.tsmodem_busy_check(util_ubus_response) then return end
        state_machine.start_timeout_timer()
        if_debug("[start_delete_sms_by_index]", "started", "")
    end

    -- Удаляет смс
    function state_machine.delete_sms_by_index_CMGF_OK_handler()
        state_machine.state = STATE.DELETE_SMS_BY_INDEX.WAITING_CMGD_OK
        state_machine.tsmodem_send_at("AT+CMGD="..tostring(state_machine.sms_index))
    end

    -- Завершает выполнение запроса
    function state_machine.delete_sms_by_index_CMGD_OK_handler()
        if state_machine.timeout_timer then state_machine.timeout_timer:cancel() end

        state_machine.app.conn:reply(state_machine.def_req, { status = UBUS_RESPONSE_STATUS.OK })
        state_machine.end_reply()
    end

    -- Обработчик состояний delete_sms_by_index, обработчики ответов AT запросов
    function state_machine.delete_sms_by_index_event_handler(at_response)
        if state_machine.state == STATE.DELETE_SMS_BY_INDEX.WAITING_CMGF_OK then
            if at_response:find("AT%+CMGF") and not at_response:find("ERROR") then -- Текстовый режим установлен
                if_debug("[delete_sms_by_index]", "CMGF_OK", "")
                state_machine.delete_sms_by_index_CMGF_OK_handler()
            elseif at_response:find("%sOK%s") then
                if_debug("[delete_sms_by_index]", "OK", "previous_ok")
            else
                if_debug("[delete_sms_by_index]", "CMGF_ERROR", "")
                state_machine.send_error()
            end
        elseif state_machine.state == STATE.DELETE_SMS_BY_INDEX.WAITING_CMGD_OK then
            if at_response:find("AT%+CMGD") and not at_response:find("ERROR") then -- Смс удалена
                if_debug("[delete_sms_by_index]", "CMGD_OK", "")
                state_machine.delete_sms_by_index_CMGD_OK_handler()
            end
        end
    end
end

return delete_sms_by_index
