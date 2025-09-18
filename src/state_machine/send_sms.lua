local STATE = require "tsmsms.constants.state"
local UBUS_RESPONSE_STATUS = require "tsmsms.constants.ubus_response_status"
local CMS_ERROR = require "tsmsms.constants.cms_error"
local sms = require "tsmsms.sms"
local util = require "luci.util"

local send_sms = {}

function send_sms.extend_state_machine(state_machine)
    function state_machine.start_send_sms(req, sms_phone, sms_text)
        if_debug("[send_sms]", "ubus request received", "")
        if state_machine.busy_check(req) then return end

        if sms_phone and sms_text then
            local sms_chunks = sms.makePduChunks(sms_phone, sms_text)

            state_machine.state = STATE.SEND_SMS.WAITING_CMGF_OK
            state_machine.send_sms.chunks = sms_chunks
            state_machine.send_sms.part = 1

            state_machine.start_reply(req)
            local util_ubus_response = state_machine.tsmodem_send_at("AT+CMGF=0")
            if state_machine.tsmodem_busy_check(util_ubus_response) then return end

            state_machine.start_timeout_timer(30000)
            if_debug("[send_sms]", "started", "")
        else
            state_machine.app.conn:reply(req, {
                status = UBUS_RESPONSE_STATUS.ERROR,
                error = "No phone or sms text got via UBUS",
            })
        end
    end

    function state_machine.send_sms_CMGF_OK_handler()
        local pdu_length = state_machine.send_sms.chunks[state_machine.send_sms.part].pdu_length
        state_machine.tsmodem_send_at(string.format("AT+CMGS=%s", pdu_length))
        state_machine.state = STATE.SEND_SMS.WAITING_CMGS_OK
    end

    function state_machine.send_sms_CMGS_OK_handler()
        local pdu_text = state_machine.send_sms.chunks[state_machine.send_sms.part].pdu_text
        state_machine.tsmodem_send_at(string.format("%s\26", pdu_text))
        state_machine.state = STATE.SEND_SMS.WAITING_PDU_TEXT_OK
    end

    function state_machine.send_sms_PDU_TEXT_OK_handler()
        if state_machine.timeout_timer then state_machine.timeout_timer:cancel() end

        if state_machine.send_sms.part < #state_machine.send_sms.chunks then
            state_machine.send_sms.part = state_machine.send_sms.part + 1
            state_machine.state = STATE.SEND_SMS.WAITING_CMGF_OK
            state_machine.tsmodem_send_at("AT+CMGF=0")
            state_machine.start_timeout_timer(30000)
            if_debug("[send_sms]", "new part started ["..tostring(state_machine.send_sms.part).."/"..tostring(#state_machine.send_sms.chunks).."]", "")
        else
            state_machine.app.conn:reply(state_machine.def_req, { status = UBUS_RESPONSE_STATUS.OK })
            state_machine.end_reply()
        end
    end

    function state_machine.send_sms_handler(at_response)
        if at_response:find("%+CMS") and at_response:find("ERROR") then
            if_debug("[send_sms]", "ERROR", at_response)

            state_machine.send_sms_error_counter = state_machine.send_sms_error_counter + 1
            if_debug("[send_sms]", "ERROR", string.format("[%s/%s]", state_machine.send_sms_error_counter, state_machine.app.uci_config.send_sms_max_attempts))

            if state_machine.send_sms_error_counter < state_machine.app.uci_config.send_sms_max_attempts then
                if state_machine.timeout_timer then state_machine.timeout_timer:cancel() end
                state_machine.state = STATE.SEND_SMS.WAITING_CMGF_OK
                state_machine.tsmodem_send_at("AT+CMGF=0")
                state_machine.start_timeout_timer(30000)

                if_debug("[send_sms]", "new sms send attempt started", "")
            else
                if_debug("[send_sms]", "ERROR", "no attempts left")

                local error_msg = at_response:match("(%+CMS ERROR: %d+)")
                local error_number = tonumber(error_msg:match("%d+"))

                local error_table = CMS_ERROR[error_number]
                local error_title = ""
                local error_description = ""

                if error_table then
                    error_title = error_table.title_ru
                    error_description = error_table.description_ru
                end

                local message = string.format("Код ошибки: %s, Название ошибки: %s, Описание ошибки: %s", error_number, error_title, error_description)

                if state_machine.app.uci_config.send_email_if_error then
                    if_debug("[send_sms]", "send error via tsmail", "")
                    util.ubus("tsmail", "send", {
                        to = state_machine.app.uci_config.email_address,
                        from = state_machine.app.uci_config.email_sender_address_tsmail,
                        subj = string.format("Ошибка при отправке SMS: %s", error_title),
                        body = message,
                    })
                end

                if_debug("[send_sms]", "send error to tsmodem.journal", "")
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

                state_machine.send_error(message)
            end
        elseif state_machine.state == STATE.SEND_SMS.WAITING_CMGF_OK then
            if at_response:find("AT%+CMGF") then
                if_debug("[send_sms]", "CMGF_OK", "")
                state_machine.send_sms_CMGF_OK_handler()
            end
        elseif state_machine.state == STATE.SEND_SMS.WAITING_CMGS_OK then
            if at_response:find("AT%+CMGS") then
                if_debug("[send_sms]", "CMGS_OK", "")
                state_machine.send_sms_CMGS_OK_handler()
            end
        elseif state_machine.state == STATE.SEND_SMS.WAITING_PDU_TEXT_OK then
            if at_response:find("%+CMGS") then
                if_debug("[send_sms]", "CMGS_OK (PDU TEXT)", "")
                state_machine.send_sms_PDU_TEXT_OK_handler()
            end
        end
    end
end

return send_sms
