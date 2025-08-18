local text_encoder = require "tsmsms.text_encoder"

local pdu_encoder = {}

function pdu_encoder.phone_number_to_PDU(phone_number)
    local result = ''

    if #phone_number % 2 == 1 then
        phone_number = phone_number .. 'F'
    end

    for i = 1, #phone_number do
        if i % 2 == 1 then
            result = result .. string.sub(phone_number, i + 1, i + 1) .. string.sub(phone_number, i, i)
        end
    end

    return result
end

function pdu_encoder.utf8_hex_length(utf8_hex)
    return string.format("%02X", #utf8_hex / 2) -- '0D' - 2 элемента в строке
end

function pdu_encoder.pdu_length(pdu)
    return tostring(math.floor(#pdu / 2) - 1)
end

function pdu_encoder.encode(recipient_number, sms_text, concatenated)
    local is_sms_concatenated = (concatenated and concatenated.part and concatenated.total_parts and concatenated.reference_number)

    local smsc_information_length = "00"
    local pdu_type = ""
    if is_sms_concatenated then
        pdu_type = "51"
    else
        pdu_type = "11"
    end
    local tp_message_reference = "00"
    local pdu_header = smsc_information_length .. pdu_type .. tp_message_reference

    local phone_number_type = ""
    if string.sub(recipient_number, 1, 1) == '+' then
        recipient_number = string.sub(recipient_number, 2)
        phone_number_type = "91"
    else
        phone_number_type = "81"
    end

    local phone_number_length = string.format("%02X", #recipient_number)
    local phone_number_PDU = pdu_encoder.phone_number_to_PDU(recipient_number)

    local pdu_middle = "00080B"

    local user_data_header = ""
    if is_sms_concatenated then
        local user_data_header_length = "05"
        local information_element_identifier = "00"
        local information_element_length = "03"
        local reference_number = string.format("%02X", concatenated.reference_number)
        local total_parts = string.format("%02X", concatenated.total_parts)
        local sms_part = string.format("%02X", concatenated.part)
        user_data_header = user_data_header_length .. information_element_identifier .. information_element_length .. reference_number .. total_parts .. sms_part
    end

    local message_hex = text_encoder.uft8_to_hex(sms_text)
    local user_data_hex = user_data_header .. message_hex
    local user_data_length = pdu_encoder.utf8_hex_length(user_data_hex)

    local pdu = pdu_header .. phone_number_length .. phone_number_type .. phone_number_PDU .. pdu_middle .. user_data_length .. user_data_hex

    local cmgs_len = pdu_encoder.pdu_length(pdu)
    return cmgs_len, pdu
end

return pdu_encoder