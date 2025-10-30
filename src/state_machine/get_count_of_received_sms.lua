-- Данный файл определяет методы необходимые для запроса "получение количества смс"

local STATE = require "tsmsms.constants.state"
local UBUS_RESPONSE_STATUS = require "tsmsms.constants.ubus_response_status"

local get_count_of_received_sms = {}

function get_count_of_received_sms.extend_state_machine(state_machine)
    -- Вызывается при начале обработки запроса
    function state_machine.start_get_count_of_received_sms(req)
        if_debug("[get_count_of_received_sms]", "ubus request received", "")
        if state_machine.busy_check(req) then return end
        state_machine.start_reply(req)

        state_machine.state = STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CMGF_OK
        local util_ubus_response = state_machine.tsmodem_send_at("AT+CMGF=1") -- Включение текстового режима
        if state_machine.tsmodem_busy_check(util_ubus_response) then return end
        state_machine.start_timeout_timer()
        if_debug("[get_count_of_received_sms]", "started", "")
    end

    -- Запрашивает состояние памяти хранилища смс
    function state_machine.get_count_of_received_sms_CMGF_OK_handler()
        state_machine.state = STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CPMS_RESULT
        state_machine.tsmodem_send_at("AT+CPMS?")
    end

    -- Завершает выполнение запроса
    function state_machine.get_count_of_received_sms_CPMS_RESULT_handler(at_response)
        if state_machine.timeout_timer then state_machine.timeout_timer:cancel() end

        local sms_count = at_response:match('"SM",(%d+)') -- Читает информацию об количестве смс
        if_debug("[get_count_of_received_sms]", "SMS_COUNT (result)", tostring(sms_count))

        state_machine.app.conn:reply(state_machine.def_req, { status = UBUS_RESPONSE_STATUS.OK, result = sms_count })
        state_machine.end_reply()
    end

    -- Обработчик состояний get_count_of_received_sms
    function state_machine.get_count_of_received_sms_event_handler(at_response)
        if state_machine.state == STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CMGF_OK then
            if at_response:find("AT%+CMGF") and not at_response:find("ERROR") then -- Текстовый режим установлен
                if_debug("[get_count_of_received_sms]", "CMGF_OK", "")
                state_machine.get_count_of_received_sms_CMGF_OK_handler()
            else
                if_debug("[get_count_of_received_sms]", "CMGF_ERROR", "")
                state_machine.send_error()
            end
        elseif state_machine.state == STATE.GET_COUNT_OF_RECEIVED_SMS.WAITING_CPMS_RESULT then
            if at_response:find("%+CPMS:") and not at_response:find("ERROR") then -- Получен ответ о состоянии
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
end

return get_count_of_received_sms
