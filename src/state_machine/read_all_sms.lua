-- Данный файл определяет методы необходимые для запроса "чтение всех смс"

local STATE = require "tsmsms.constants.state"
local UBUS_RESPONSE_STATUS = require "tsmsms.constants.ubus_response_status"
local pdu_decoder = require "tsmsms.pdu_decoder"
local util = require "luci.util"

local read_all_sms = {}

function read_all_sms.extend_state_machine(state_machine)
    -- Вызывается при начале обработки запроса
    function state_machine.start_read_all_sms(req)
        if_debug("[read_all_sms]", "ubus request received", "")
        if state_machine.busy_check(req) then return end
        state_machine.start_reply(req)

        state_machine.read_all_sms_buffer = {}
        state_machine.state = STATE.READ_ALL_SMS.WAITING_CMGF_OK
        local util_ubus_response = state_machine.tsmodem_send_at("AT+CMGF=0") -- Включение PDU режима
        if state_machine.tsmodem_busy_check(util_ubus_response) then return end
        state_machine.start_timeout_timer()
        if_debug("[read_all_sms]", "started", "")
    end

    -- Отправляет запрос на чтение всех смс
    function state_machine.read_all_sms_CMGF_OK_handler()
        state_machine.state = STATE.READ_ALL_SMS.WAITING_CMGL_RESULT
        state_machine.tsmodem_send_at("AT+CMGL=4")
    end

    -- Записывает PDU данные по частям из ответа в буфер
    function state_machine.read_all_sms_CMGL_SMS_DATA_handler(at_response)
        state_machine.read_all_sms_buffer[#state_machine.read_all_sms_buffer+1] = at_response
    end

    -- Читает полученные смс и завершает выполнение запроса
    function state_machine.read_all_sms_CMGL_OK_handler()
        if state_machine.timeout_timer then state_machine.timeout_timer:cancel() end

        local response = {}

        -- Чтение смс по одной из буфера
        for i = 1, #state_machine.read_all_sms_buffer do
            local at_response_sms_data = state_machine.read_all_sms_buffer[i]
            local sms_index = at_response_sms_data:match('CMGL:%s*(%d+)')

            local pdu_data = ""
            local pdu_data_length_counter = 0

            -- Читает PDU данные смс из строки ответа
            for j = #at_response_sms_data, 1, -1 do
                local char = at_response_sms_data:sub(j, j)

                -- Если символ равен 0-9 или A-F
                if (string.byte(char) >= string.byte("0") and string.byte(char) <= string.byte("9")) or (string.byte(char) >= string.byte("A") and string.byte(char) <= string.byte("F")) then
                    pdu_data = char .. pdu_data
                    pdu_data_length_counter = pdu_data_length_counter + 1
                else -- Если другой символ
                    if pdu_data_length_counter > 10 then -- Прочитанные данные больше 10 символов, значит прочитались PDU данные
                        break
                    else -- Сброс переменных для чтения, т.к прочитанные данные не являются PDU данными
                        pdu_data = ""
                        pdu_data_length_counter = 0
                    end
                end
            end

            local parsed_sms = pdu_decoder.parse(pdu_data) -- Парсинг смс данных из PDU

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

    -- Обработчик состояний read_all_sms
    function state_machine.read_all_sms_handler(at_response)
        if state_machine.state == STATE.READ_ALL_SMS.WAITING_CMGF_OK then
            if at_response:find("AT%+CMGF") and not at_response:find("ERROR") then -- PDU режим включен
                if_debug("[read_all_sms]", "CMGF_OK", "")
                state_machine.read_all_sms_CMGF_OK_handler()
            else
                if_debug("[read_all_sms]", "CMGF_ERROR", "")
                state_machine.send_error()
            end
        elseif state_machine.state == STATE.READ_ALL_SMS.WAITING_CMGL_RESULT then
            if at_response:find("%+CMGL:") then -- Записывает ответ (pdu данные смс) в буфер
                if_debug("[read_all_sms]", "CMGL_SMS_DATA", "")
                state_machine.read_all_sms_CMGL_SMS_DATA_handler(at_response)
                if at_response:find("OK") then -- При завершении записи всех смс в буфер, вызывается парсер-обработчик смс
                    if_debug("[read_all_sms]", "CMGL_OK", "")
                    state_machine.read_all_sms_CMGL_OK_handler()
                end
            elseif at_response:find("^%s*OK%s*$") then -- Если "OK" ответ пришел отдельно, то также вызывается парсер-обработчик смс
                if_debug("[read_all_sms]", "CMGL_OK", "")
                state_machine.read_all_sms_CMGL_OK_handler()
            elseif not at_response:find("AT%+CMGL=4") then
                if_debug("[read_all_sms]", "CMGL_ERROR", "")
                state_machine.send_error()
            end
        end
    end
end

return read_all_sms
