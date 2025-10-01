local socket = require "socket"

local test = {
    passed = 0,
    failed = 0,
    start_time = 0,
}

local ESC = string.char(27)
local color = {
    green = ESC .. "[1;32m",
    red = ESC .. "[1;31m",
    reset = ESC .. "[0m",
}

local OK = "[" .. color.green .. "OK" .. color.reset .. "]"
local FAIL = "[" .. color.red .. "FAIL" .. color.reset .. "]"

local function get_test_time()
    local end_time = socket.gettime()
    local time_diff = (end_time - test.start_time) * 1000
    test.start_time = 0
    return string.format("%.2f", time_diff)
end

function test.run(func, times)
    if not times then
        times = 1
    end

    for i = 1, times do
        test.start_time = socket.gettime()
        local status, err = pcall(func)
    end
end

function test.assert_true(msg, result)
    local ms_time = get_test_time()

    if result == true then
        print(string.format("%s %s (%s ms)", OK, msg, ms_time))
        test.passed = test.passed + 1
    else
        print(string.format("%s %s (%s ms)", FAIL, msg, ms_time))
        print("  Details:")
        print(string.format("    Expected: %q (%s)", tostring(true), type(true)))
        print(string.format("    Actual: %q (%s)", tostring(result), type(result)))
        test.failed = test.failed + 1
    end
end

function test.assert_false(msg, result)
    local ms_time = get_test_time()

    if result == false then
        print(string.format("%s %s (%s ms)", OK, msg, ms_time))
        test.passed = test.passed + 1
    else
        print(string.format("%s %s (%s ms)", FAIL, msg, ms_time))
        print("  Details:")
        print(string.format("    Expected: %q (%s)", tostring(false), type(false)))
        print(string.format("    Actual: %q (%s)", tostring(result), type(result)))
        test.failed = test.failed + 1
    end
end

function test.assert_equal(msg, expected, result)
    local ms_time = get_test_time()

    if expected == result then
        print(string.format("%s %s (%s ms)", OK, msg, ms_time))
        test.passed = test.passed + 1
    else
        print(string.format("%s %s (%s ms)", FAIL, msg, ms_time))
        print("  Details:")
        print(string.format("    Expected: %q (%s)", tostring(expected), type(expected)))
        print(string.format("    Actual: %q (%s)", tostring(result), type(result)))
        test.failed = test.failed + 1
    end
end

function test.assert_match(msg, pattern, result)
    local ms_time = get_test_time()

    if result:match(pattern) then
        print(string.format("%s %s (%s ms)", OK, msg, ms_time))
        test.passed = test.passed + 1
    else
        print(string.format("%s %s (%s ms)", FAIL, msg, ms_time))
        print("  Details:")
        print(string.format("    Match pattern: %q", pattern))
        print(string.format("    Got text: %q", string.gsub(result, "\n", "\\n")))
        test.failed = test.failed + 1
    end
end

function test.print_results()
    local result = string.format("Total tests: %d | Passed: %d | Failed: %d", test.passed + test.failed, test.passed, test.failed)
    local divider = string.rep('─', #result + 2)

    print("┌"..divider.."┐")
    print("│ "..result.." │")
    print("└"..divider.."┘")

    test.passed = 0
    test.failed = 0
end

return test
