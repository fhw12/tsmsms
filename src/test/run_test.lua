local test = require "tsmsms.test.test"
local cjson = require "cjson"

local pdu_decoder = require "tsmsms.pdu_decoder"
local pdu_encoder = require "tsmsms.pdu_encoder"
local sms = require "tsmsms.sms"
local text_decoder = require "tsmsms.text_decoder"
local text_encoder = require "tsmsms.text_encoder"
require "tsmsms.util"

-- print(pdu_decoder)
-- print(pdu_encoder)
-- print(sms)
-- print(text_decoder)
-- print(text_encoder)
-- print(if_debug, split_message)

local function create_bash_tsmsms_ubus_call(method, params)
    return "ubus call tsmodem.sms " .. method .. " '" .. cjson.encode(params) .. "' 2>&1"
end

local function run_bash(bash)
    local ubus_process = io.popen(bash)
    local result = ""
    if ubus_process ~= nil then
        result = ubus_process:read("*a")
        ubus_process:close()
    end
    return result
end

test.run(function ()
    local cmd = create_bash_tsmsms_ubus_call("get_count_of_received_sms", {})
    local result = run_bash(cmd)
    test.assert_match("Get count of received sms is ok", "ok", result)
end, 1)

test.run(function ()
    local cmd = create_bash_tsmsms_ubus_call("read_sms_by_index", { index = 1 })
    local result = run_bash(cmd)
    test.assert_match("Read sms by index is ok", "ok", result)
end, 1)

test.run(function ()
    local read_all_sms = create_bash_tsmsms_ubus_call("read_all_sms", {})
    local read_all_sms_result = run_bash(read_all_sms)
    test.assert_match("Read all sms is ok", "ok", read_all_sms_result)
end, 1)

test.run(function ()
    local delete_sms = create_bash_tsmsms_ubus_call("delete_sms_by_index", { index = 10 })
    local delete_sms_result = run_bash(delete_sms)
    test.assert_match("Delete sms by index is ok", "ok", delete_sms_result)
end, 1)

test.run(function ()
    local cmd = create_bash_tsmsms_ubus_call("send_sms", { phone = "000100", text = "b" })
    local result = run_bash(cmd)
    test.assert_match("Send sms is ok", "ok", result)
end)

----------------------------------------------------------------------------
-- local pdu_data_length, pdu_data = pdu_encoder.encode('000100', 'balance')
-- local sms_data = pdu_decoder.parse(pdu_data)
-- -- print(sms_data.message_text)
-- print(pdu_data)
-- for key, value in pairs(sms_data) do
--     print(key, value)
-- end

-- local text = "Text"
-- local hex = text_encoder.uft8_to_hex(text)
-- print( text_decoder.utf16be_to_utf8(hex) )
----------------------------------------------------------------------------

test.run(function ()
    local hex_text = "D4329E0E" -- "Text" string in gsm7bit
    test.assert_equal("text_decoder.gsm7bit_to_text(hex_text) == original text", "Text", text_decoder.gsm7bit_to_text(hex_text))
end)

test.run(function ()
    local text = text_decoder.utf16be_to_utf8(text_encoder.uft8_to_hex("Text"))
    test.assert_equal('text_decoder.utf16be_to_utf8(text_encoder.uft8_to_hex(text)) result == original text', "Text", text)
end)

test.run(function ()
    local received_sms_pdu = "07919732520111F20406810010000008520110317044821604110430043B0430043D044100200032003000200440"
    local sms_data_from_pdu = pdu_decoder.parse(received_sms_pdu)
    local i = 0
    for _, _ in pairs(sms_data_from_pdu) do
       i = i + 1
    end
    test.assert_true("sms pdu data parsed", i > 0)
end)

test.run(function ()
    local pdu_length, pdu_data = pdu_encoder.encode("000100", "balance")
    test.assert_true('pdu_encoder.encode(), pdu_length > 0 and #pdu_data > 0', tonumber(pdu_length) > 0 and #pdu_data > 0)
end)

test.run(function ()
    local chunks = sms.makePduChunks("000100", "balance")
    test.assert_true("sms.makePduChunks(), #chunks > 0", #chunks > 0)
end)

-- todo test: split_message, get_sms_pdu_data_from_at_response (from util.lua)
-- test.run(function ()
-- end)

test.print_results()