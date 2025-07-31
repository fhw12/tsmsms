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

function pdu_encoder.utf8_hex_message_length(utf8_hex)
    return string.format("%02X", #utf8_hex / 2) -- '0D' - 2 элемента в строке
end

function pdu_encoder.pdu_length(pdu)
    return tostring(math.floor(#pdu / 2) - 1)
end

function pdu_encoder.encode(recipient_number, sms_text)
    local pdu_head = "001100"

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

    local message_hex = text_encoder.uft8_to_hex(sms_text)
    local message_length = pdu_encoder.utf8_hex_message_length(message_hex)

    local pdu = pdu_head .. phone_number_length .. phone_number_type .. phone_number_PDU .. pdu_middle .. message_length .. message_hex

    local cmgs_len = pdu_encoder.pdu_length(pdu)
    return cmgs_len, pdu
end

return pdu_encoder