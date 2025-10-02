local socket = require "socket"

local test = {
    mode = {
        default = 0,
        info = 1,
    }
}

local test_data = {
    passed = 0,
    failed = 0,
    start_time = 0,
    mode = test.mode.default,
}

local ESC = string.char(27)
local color = {
    green = ESC .. "[1;32m",
    red = ESC .. "[1;31m",
    yellow = ESC .. "[1;33m",
    reset = ESC .. "[0m",
}

local OK = "[" .. color.green .. "OK" .. color.reset .. "]"
local FAIL = "[" .. color.red .. "FAIL" .. color.reset .. "]"
local INFO = "{" .. color.yellow .. "info" .. color.reset .. "}"

local function get_test_time_str()
    local end_time = socket.gettime()
    local time_diff = (end_time - test_data.start_time) * 1000
    test_data.start_time = 0
    return string.format("%.2f", time_diff)
end

local function get_test_mode_str()
    if test_data.mode == test.mode.default then
        return ""
    elseif test_data.mode == test.mode.info then
        return INFO .. " "
    else
        return ""
    end
end

function test.run(func, mode, times)
    if not times then
        times = 1
    end

    if not mode then
        test_data.mode = test.mode.default
    else
        test_data.mode = mode
    end

    for i = 1, times do
        test_data.start_time = socket.gettime()
        local status, err = pcall(func)
    end
end

function test.assert_true(msg, result)
    local ms_time = get_test_time_str()

    if result == true then
        print(string.format("%s %s%s (%s ms)", OK, get_test_mode_str(), msg, ms_time))
        test_data.passed = test_data.passed + 1
    else
        print(string.format("%s %s%s (%s ms)", FAIL, get_test_mode_str(), msg, ms_time))
        print("  Details:")
        print(string.format("    Expected: %q (%s)", tostring(true), type(true)))
        print(string.format("    Actual: %q (%s)", tostring(result), type(result)))
        test_data.failed = test_data.failed + 1
    end
end

function test.assert_false(msg, result)
    local ms_time = get_test_time_str()

    if result == false then
        print(string.format("%s %s%s (%s ms)", OK, get_test_mode_str(), msg, ms_time))
        test_data.passed = test_data.passed + 1
    else
        print(string.format("%s %s%s (%s ms)", FAIL, get_test_mode_str(), msg, ms_time))
        print("  Details:")
        print(string.format("    Expected: %q (%s)", tostring(false), type(false)))
        print(string.format("    Actual: %q (%s)", tostring(result), type(result)))
        test_data.failed = test_data.failed + 1
    end
end

function test.assert_equal(msg, expected, result)
    local ms_time = get_test_time_str()

    if expected == result then
        print(string.format("%s %s%s (%s ms)", OK, get_test_mode_str(), msg, ms_time))
        test_data.passed = test_data.passed + 1
    else
        print(string.format("%s %s%s (%s ms)", FAIL, get_test_mode_str(), msg, ms_time))
        print("  Details:")
        print(string.format("    Expected: %q (%s)", tostring(expected), type(expected)))
        print(string.format("    Actual: %q (%s)", tostring(result), type(result)))
        test_data.failed = test_data.failed + 1
    end
end

function test.assert_match(msg, pattern, result)
    local ms_time = get_test_time_str()

    if result:match(pattern) then
        print(string.format("%s %s%s (%s ms)", OK, get_test_mode_str(), msg, ms_time))
        test_data.passed = test_data.passed + 1
    else
        print(string.format("%s %s%s (%s ms)", FAIL, get_test_mode_str(), msg, ms_time))
        print("  Details:")
        print(string.format("    Match pattern: %q", pattern))
        print(string.format("    Got text: %q", string.gsub(result, "\n", "\\n")))
        test_data.failed = test_data.failed + 1
    end
end

function test.print_results()
    local total = test_data.passed + test_data.failed
    local result = string.format("Total tests: %d | Passed: %d | Failed: %d", total, test_data.passed, test_data.failed)
    local divider = string.rep('─', #result + 2)

    print("┌"..divider.."┐")
    print("│ "..result.." │")
    print("└"..divider.."┘")

    test_data.passed = 0
    test_data.failed = 0
end

return test
