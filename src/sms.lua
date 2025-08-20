local pdu_encoder = require "tsmsms.pdu_encoder"
require "tsmsms.util"


local sms = {}

function sms.makePduChunks(phone_number, msg_text)
    local msg_parts = split_message(msg_text, 67)
    local sms_chunks = {}
    local concatenated_reference_number = 0

    if #msg_parts > 1 then
        math.randomseed(os.time())
        concatenated_reference_number = math.random(0, 255)
    end

    for n, msg_part in ipairs(msg_parts) do
        local concatenated = nil

        if #msg_parts > 1 then
            concatenated = {
                part = n,
                total_parts = #msg_parts,
                reference_number = concatenated_reference_number,
            }
        end

        local pdu_length, pdu_text = pdu_encoder.encode(phone_number, msg_part, concatenated)
        sms_chunks[#sms_chunks+1] = { pdu_length = pdu_length, pdu_text = pdu_text }
    end

    return sms_chunks
end

return sms