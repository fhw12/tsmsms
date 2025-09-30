local test = require "test"
local cjson = require "cjson"

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

local get_count_of_received_sms = create_bash_tsmsms_ubus_call("get_count_of_received_sms", {})
local read_sms = create_bash_tsmsms_ubus_call("read_sms_by_index", { index = 1 })

local get_count_of_received_sms_result = run_bash(get_count_of_received_sms)
test.assert_match("Get count of received sms is ok", "ok", get_count_of_received_sms_result)

get_count_of_received_sms_result = run_bash(get_count_of_received_sms)
test.assert_match("Get count of received sms is ok", "ok", get_count_of_received_sms_result)

get_count_of_received_sms_result = run_bash(get_count_of_received_sms)
test.assert_match("Get count of received sms, match 123 substring in result", "123", get_count_of_received_sms_result)

get_count_of_received_sms_result = run_bash(get_count_of_received_sms)
test.assert_match("Get count of received sms is ok", "ok", get_count_of_received_sms_result)

get_count_of_received_sms_result = run_bash(get_count_of_received_sms)
test.assert_match("Get count of received sms is ok", "ok", get_count_of_received_sms_result)

get_count_of_received_sms_result = run_bash(get_count_of_received_sms)
test.assert_match("Get count of received sms is ok", "ok", get_count_of_received_sms_result)

get_count_of_received_sms_result = run_bash(get_count_of_received_sms)
test.assert_match("Get count of received sms is ok", "ok", get_count_of_received_sms_result)

local read_sms_result = run_bash(read_sms)
test.assert_match("Read sms by index is ok", "ok", read_sms_result)

read_sms_result = run_bash(read_sms)
test.assert_match("Read sms by index is ok", "ok", read_sms_result)

read_sms_result = run_bash(read_sms)
test.assert_match("Read sms by index is ok", "ok", read_sms_result)

test.print_results()
