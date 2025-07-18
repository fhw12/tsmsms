local text_decoder = require "tsmsms.text_decoder"

local pdu_decoder = {}

function pdu_decoder.parse(msg)
    local p = 1

    local smsc_length = msg:sub(p, p + 1)
    print("[pdu_decoder.lua] smsc_length: ", smsc_length)
    p = p + 2

    local smsc_address_type = msg:sub(p, p + 1)
    print("[pdu_decoder.lua] smsc_address_type: ", smsc_address_type)
    p = p + 2

    local service_center_number = "+"
    for i = 0, tonumber(smsc_length, 16) - 2 do
        local digits = msg:sub(p, p + 1)
        p = p + 2

        local first_digit = digits:sub(2, 2)
        local second_digit = digits:sub(1, 1)

        if i == tonumber(smsc_length, 16) - 2 then
            second_digit = ""
        end

        service_center_number = service_center_number .. first_digit .. second_digit
    end
    print("[pdu_decoder.lua] service_center_number: ", service_center_number)

    local message_type = msg:sub(p, p + 1)
    print("[pdu_decoder.lua] message_type", message_type)
    p = p + 2

    local sender_address_length = msg:sub(p, p + 1)
    print("[pdu_decoder.lua] sender_address_length: ", sender_address_length)
    p = p + 2

    local sender_address_type = msg:sub(p, p + 1)
    print("[pdu_decoder.lua] sender_address_type: ", sender_address_type)
    p = p + 2

    local sender_number = "+"
    for i = 0, math.ceil(tonumber(sender_address_length, 16) / 2) - 1 do
        local digits = msg:sub(p, p + 1)
        p = p + 2

        local first_digit = digits:sub(2, 2)
        local second_digit = digits:sub(1, 1)

        if i == math.ceil(tonumber(sender_address_length, 16) / 2) - 1 then
            second_digit = ""
        end

        sender_number = sender_number .. first_digit .. second_digit
    end
    print("[pdu_decoder.lua] sender_number: ", sender_number)

    local protocol_identifier = msg:sub(p, p + 1)
    print("[pdu_decoder.lua] protocol_identifier: ", protocol_identifier)
    p = p + 2

    local data_coding_scheme = msg:sub(p, p + 1)
    print("[pdu_decoder.lua] data_coding_scheme: ", data_coding_scheme)
    p = p + 2

    local date = ""
    for i = 0, 6 do
        local digits = msg:sub(p, p + 1)
        p = p + 2

        local first_digit = digits:sub(2, 2)
        local second_digit = digits:sub(1, 1)

        date = date .. first_digit .. second_digit .. " "
    end
    print("[pdu_decoder.lua] date: ", date)

    local user_date_length = msg:sub(p, p + 1)
    print("[pdu_decoder.lua] user_date_length: ", user_date_length)
    p = p + 2

    local message_hex = msg:sub(p, #msg)
    print("[pdu_decoder.lua] message_hex: ", message_hex)

    local message_text = ""
    if data_coding_scheme == "08" then
        message_text = text_decoder.utf16be_to_utf8(message_hex)
    elseif data_coding_scheme == "00" then
        message_text = text_decoder.gsm7bit_to_text(message_hex)
    end

    return {
        sender = sender_number,
        sender_address_type = sender_address_type,
        message = message_hex,
        decoded_message = message_text,
        data_coding_scheme = data_coding_scheme,
    }
end

return pdu_decoder