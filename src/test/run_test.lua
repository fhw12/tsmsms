local test = require "tsmsms.test.test"
local cjson = require "cjson"

local pdu_decoder = require "tsmsms.pdu_decoder"
local pdu_encoder = require "tsmsms.pdu_encoder"
local sms = require "tsmsms.sms"
local text_decoder = require "tsmsms.text_decoder"
local text_encoder = require "tsmsms.text_encoder"
require "tsmsms.util"


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
end, test.mode.default, 1)

test.run(function ()
    local cmd = create_bash_tsmsms_ubus_call("read_sms_by_index", { index = 1 })
    local result = run_bash(cmd)
    test.assert_match("Read sms by index is ok", "ok", result)
end, test.mode.default, 1)

test.run(function ()
    local read_all_sms = create_bash_tsmsms_ubus_call("read_all_sms", {})
    local read_all_sms_result = run_bash(read_all_sms)
    test.assert_match("Read all sms is ok", "ok", read_all_sms_result)
end, test.mode.default, 1)

test.run(function ()
    local delete_sms = create_bash_tsmsms_ubus_call("delete_sms_by_index", { index = 10 })
    local delete_sms_result = run_bash(delete_sms)
    test.assert_match("Delete sms by index is ok", "ok", delete_sms_result)
end, test.mode.default, 1)

test.run(function ()
    local cmd = create_bash_tsmsms_ubus_call("send_sms", { phone = "000100", text = "b" })
    local result = run_bash(cmd)
    test.assert_match("Send sms is ok", "ok", result)
end, test.mode.default, 1)

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
    test.assert_true(
        {
            name = "sms pdu data parsed",
            description = "Тест проверяет только наличие смс данных, для точной проверки необходимо распарсить данные через стороннюю утилиту и сравнить данные",
        },
        i > 0
    )
end, test.mode.info)

test.run(function ()
    local pdu_length, pdu_data = pdu_encoder.encode("000100", "balance")
    test.assert_true(
        {
            name = 'pdu_encoder.encode(), pdu_length > 0 and #pdu_data > 0',
            description = "Нет возможности проверить правильность PDU данных для отправки смс, тест проверяет только наличие этих данных",
        },
        tonumber(pdu_length) > 0 and #pdu_data > 0
    )
end, test.mode.info)

test.run(function ()
    local chunks = sms.makePduChunks("000100", "balance")
    test.assert_true(
        {
            name = "sms.makePduChunks(), #chunks > 0",
            description = "Нет возможности проверить кусочки смс на их правильность, тест проверяет только их наличие",
        },
        #chunks > 0
    )
end, test.mode.info)

test.run(function()
    local result = split_message('1234567890', 3)
    test.assert_true('split_message function works', result[1] == "123" and result[2] == "456" and result[3] == "789" and result[4] == "0")
end)

test.run(function ()
    local correct_pdu_data = "07919732520111F20406810010000008520120016253821604110430043B0430043D044100200032003000200440"
    local AT_response = "\r\
+CMGR: 1,,38\r\
07919732520111F20406810010000008520120016253821604110430043B0430043D044100200032003000200440\r\
\r\
OK\r\
"
    local pdu_data = get_sms_pdu_data_from_at_response(AT_response)
    test.assert_equal('get_sms_pdu_data_from_at_response function works', correct_pdu_data, pdu_data)
end)


test.print_results()
