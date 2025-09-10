local cjson = require "cjson"
local socket = require "socket"

local test = {
    counters = {
        all = {
            ok = 0,
            error = 0,
            busy = 0,
            timeout = 0,
            request = 0
        },
        tmp = {
            ok = 0,
            error = 0,
            busy = 0,
            timeout = 0,
            request = 0,
        },
    },
}

function test.create_bash_tsmsms_ubus_call(method, params)
    return "ubus call tsmodem.sms " .. method .. " '" .. cjson.encode(params) .. "' 2>&1"
end

function test.run_bash(bash)
    local ubus_process = io.popen(bash)
    local result = ""
    if ubus_process ~= nil then
        result = ubus_process:read("*a")
        ubus_process:close()
    end
    return result
end

function test.reset_tmp_counters()
    test.counters.all.ok = test.counters.all.ok + test.counters.tmp.ok
    test.counters.all.error = test.counters.all.error + test.counters.tmp.error
    test.counters.all.busy = test.counters.all.busy + test.counters.tmp.busy
    test.counters.all.timeout = test.counters.all.timeout + test.counters.tmp.timeout
    test.counters.all.request = test.counters.all.request + test.counters.tmp.request

    test.counters.tmp.ok = 0
    test.counters.tmp.error = 0
    test.counters.tmp.busy = 0
    test.counters.tmp.timeout = 0
    test.counters.tmp.request = 0
end

function test.print_test_result(counters)
    print("ok", counters.ok .. "(" .. tostring(counters.ok / counters.request * 100) .. "%)")
    print("error", counters.error .. "(" .. tostring(counters.error / counters.request * 100) .. "%)")
    print("busy", counters.busy .. "(" .. tostring(counters.busy / counters.request * 100) .. "%)")
    print("timeout", counters.timeout .. "(" .. tostring(counters.timeout / counters.request * 100) .. "%)")
    print("requests", counters.request)
end

function test.get_count_of_received_sms()
    return test.tsmsms_ubus("get_count_of_received_sms", {})
end

function test.read_sms_by_index(index)
    return test.tsmsms_ubus("read_sms_by_index", { index = index })
end

function test.read_all_sms()
    return test.tsmsms_ubus("read_all_sms", {})
end

function test.delete_sms_by_index(index)
    return test.tsmsms_ubus("delete_sms_by_index", { index = index })
end

function test.send_sms(phone, text)
    return test.tsmsms_ubus("send_sms", { phone = phone, text = text })
end

function test.run_test(bash, stop_if_error)
    test.reset_tmp_counters()
    print("test ubus request", bash)

    for i = 1, 100 do
        local result = test.run_bash(bash)

        if result:find("Command failed: Not found") then
            print("tsmsms is not running")
            return
        end

        if result:find("error") then
            test.counters.tmp.error = test.counters.tmp.error + 1
            print("request: ", i, "error")
            if stop_if_error and stop_if_error == true then
                print("stop_if_error", bash)
                test.counters.tmp.request = test.counters.tmp.request + 1
                break
            end
        elseif result:find("busy") then
            test.counters.tmp.busy = test.counters.tmp.busy + 1
            print("request: ", i, "busy")
        elseif result:find("timeout_counter") then
            test.counters.tmp.timeout = test.counters.tmp.timeout + 1
            print("request: ", i, "timeout")
        else
            test.counters.tmp.ok = test.counters.tmp.ok + 1
            print("request: ", i, "ok")
        end

        test.counters.tmp.request = test.counters.tmp.request + 1
        socket.sleep(1)
    end

    test.print_test_result(test.counters.tmp)
    print("\n\n")
end

test.run_test(test.create_bash_tsmsms_ubus_call("get_count_of_received_sms", {}), true)
test.run_test(test.create_bash_tsmsms_ubus_call("read_sms_by_index", { index = 1 }), true)
test.run_test(test.create_bash_tsmsms_ubus_call("read_all_sms", {}), true)
test.run_test(test.create_bash_tsmsms_ubus_call("delete_sms_by_index", { index = 10 }), true)
-- test.run_test(test.create_bash_tsmsms_ubus_call("send_sms", { phone = "000100", text = "Balance" }))

print("all tests result:")
test.print_test_result(test.counters.all)