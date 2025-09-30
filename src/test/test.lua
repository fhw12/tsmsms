local test = {
    passed = 0,
    failed = 0,
}

local ESC = string.char(27)
local color = {
    green = ESC .. "[1;32m",
    red = ESC .. "[1;31m",
    reset = ESC .. "[0m",
}

-- local OK = "[" .. ESC .. "[1;32mOK" .. ESC .. "[0m]"
-- local FAIL = "[" .. ESC .. "[1;31mFAIL" .. ESC .. "[0m]"
local OK = "[" .. color.green .. "OK" .. color.reset .. "]"
local FAIL = "[" .. color.red .. "FAIL" .. color.reset .. "]"

-- function test.print_ok(msg)
--     print(string.format("%s %s", OK, msg))
-- end

-- function test.print_fail(msg)
--     print(string.format("%s %s", FAIL, msg))
-- end

function test.assert_true(result)
    -- local info = debug.getinfo(2)
    -- for key, value in pairs(info) do
    --     print(key, value)
    -- end

    if result == true then
        print(string.format("%s", OK))
    else
        print(string.format("%s expected %s, got %s", FAIL, tostring(true), tostring(result)))
    end
end

function test.assert_false(result)
    if result == false then
        print(string.format("%s", OK))
    else
        print(string.format("%s expected %s, got %s", FAIL, tostring(false), tostring(result)))
    end
end

function test.assert_equal(expected, result)
    if result == expected then
        print(string.format("%s", OK))
    else
        print(string.format("%s expected %s, got %s", FAIL, tostring(expected), tostring(result)))
    end
end

-- function test.assert_match(msg, pattern, result)
--     if result:match(pattern) then
--         print(string.format("%s %s", OK, msg))
--     else
--         result = color_start .. result .. color_end
--         print(string.format("%s expected match pattern %s, got %s", FAIL, tostring(pattern), tostring(result)))
--     end
-- end

-- todo: rewrite assert_true, assert_false, assert_equal
function test.assert_match(msg, pattern, result)
    if result:match(pattern) then
        print(string.format("%s %s", OK, msg))
        test.passed = test.passed + 1
    else
        -- result = color_start .. result .. color_end
        -- print(string.format("%s expected match pattern %s, got %s", FAIL, tostring(pattern), tostring(result)))
        print(string.format("%s %s", FAIL, msg))
        print("  Details:")
        print(string.format("    Match pattern: %q", pattern))
        print(string.format("    Got text: %s", string.gsub(result, "\n", "\\n")))
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
