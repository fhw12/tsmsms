-- test.lua - shared code для реализации тестов

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

local function get_name_and_description(test_info)
    if type(test_info) == "string" then
        return test_info, ""
    elseif type(test_info) == "table" then
        return test_info.name, test_info.description
    end
end

local function print_description(description, include_details_label)
    if description and description ~= "" then
        if include_details_label and include_details_label == true then
            print("  Details:")
        end
        print(string.format("    Description: %s", description))
    end
end


-- Запускает экземпляр теста
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

-- Положительный результат выполнения теста, если результат равен true
function test.assert_true(test_info, result)
    local name, description = get_name_and_description(test_info)
    local ms_time = get_test_time_str()

    if result == true then
        print(string.format("%s %s%s (%s ms)", OK, get_test_mode_str(), name, ms_time))
        print_description(description, true)
        test_data.passed = test_data.passed + 1
    else
        print(string.format("%s %s%s (%s ms)", FAIL, get_test_mode_str(), name, ms_time))
        print("  Details:")
        print_description(description)
        print(string.format("    Expected: %q (%s)", tostring(true), type(true)))
        print(string.format("    Actual: %q (%s)", tostring(result), type(result)))
        test_data.failed = test_data.failed + 1
    end
end

-- Положительный результат выполнения теста, если результат равен false
function test.assert_false(test_info, result)
    local name, description = get_name_and_description(test_info)
    local ms_time = get_test_time_str()

    if result == false then
        print(string.format("%s %s%s (%s ms)", OK, get_test_mode_str(), name, ms_time))
        print_description(description, true)
        test_data.passed = test_data.passed + 1
    else
        print(string.format("%s %s%s (%s ms)", FAIL, get_test_mode_str(), name, ms_time))
        print("  Details:")
        print_description(description)
        print(string.format("    Expected: %q (%s)", tostring(false), type(false)))
        print(string.format("    Actual: %q (%s)", tostring(result), type(result)))
        test_data.failed = test_data.failed + 1
    end
end

-- Положительный результат выполнения текста, если результат равен ожидаемому значению
function test.assert_equal(test_info, expected, result)
    local name, description = get_name_and_description(test_info)
    local ms_time = get_test_time_str()

    if expected == result then
        print(string.format("%s %s%s (%s ms)", OK, get_test_mode_str(), name, ms_time))
        print_description(description, true)
        test_data.passed = test_data.passed + 1
    else
        print(string.format("%s %s%s (%s ms)", FAIL, get_test_mode_str(), name, ms_time))
        print("  Details:")
        print_description(description)
        print(string.format("    Expected: %q (%s)", tostring(expected), type(expected)))
        print(string.format("    Actual: %q (%s)", tostring(result), type(result)))
        test_data.failed = test_data.failed + 1
    end
end

-- Положительный результат выполнения текста, если результат соответствует паттерну
function test.assert_match(test_info, pattern, result)
    local name, description = get_name_and_description(test_info)
    local ms_time = get_test_time_str()

    if result:match(pattern) then
        print(string.format("%s %s%s (%s ms)", OK, get_test_mode_str(), name, ms_time))
        print_description(description, true)
        test_data.passed = test_data.passed + 1
    else
        print(string.format("%s %s%s (%s ms)", FAIL, get_test_mode_str(), name, ms_time))
        print("  Details:")
        print_description(description)
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
