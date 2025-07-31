local text_encoder = {}

function text_encoder.uft8_to_hex(str)
    local code_points = {}
    local i = 1
    while i <= #str do
        local char = string.byte(str, i)
        if char <= 127 then -- ASCII
            table.insert(code_points, char)
            i = i + 1
        elseif char >= 192 and char <= 223 then -- 2 байта
            table.insert(code_points, ((char - 192) * 64) + (string.byte(str, i + 1) - 128))
            i = i + 2
        elseif char >= 224 and char <= 239 then -- 3 байта
            table.insert(code_points, ((char - 224) * 4096) + ((string.byte(str, i + 1) - 128) * 64) + (string.byte(str, i + 2) - 128))
            i = i + 3
        elseif char >= 240 and char <= 247 then -- 4 байта
            table.insert(code_points, ((char - 240) * 262144) + ((string.byte(str, i + 1) - 128) * 4096) + ((string.byte(str, i + 2) - 128) * 64) + (string.byte(str, i + 3) - 128))
            i = i + 4
        elseif char >= 248 and char <= 251 then -- 5 байт
            table.insert(code_points, ((char - 248) * 16777216) + ((string.byte(str, i + 1) - 128) * 262144) + ((string.byte(str, i + 2) - 128) * 4096) + ((string.byte(str, i + 3) - 128) * 64) + (string.byte(str, i + 4) - 128))
            i = i + 5
        elseif char >= 252 and char <= 253 then -- 6 байт
            table.insert(code_points, ((char - 252) * 1073741824) + ((string.byte(str, i + 1) - 128) * 16777216) + ((string.byte(str, i + 2) - 128) * 262144) + ((string.byte(str, i + 3) - 128) * 4096) + ((string.byte(str, i + 4) - 128) * 64) + (string.byte(str, i + 5) - 128))
            i = i + 6
        elseif char >= 254 and char <= 255 then -- 7 байт (редкое)
            table.insert(code_points, ((char - 254) * 68719476736) + ((string.byte(str, i + 1) - 128) * 1073741824) + ((string.byte(str, i + 2) - 128) * 16777216) + ((string.byte(str, i + 3) - 128) * 262144) + ((string.byte(str, i + 4) - 128) * 4096) + ((string.byte(str, i + 5) - 128) * 64) + (string.byte(str, i + 6) - 128))
            i = i + 7
        else
            error("Неподдерживаемый символ: " .. string.char(char))
        end
    end
    -- Преобразование из таблицы в сроку в HEX формате
    local result = {}
    for _, code_point in ipairs(code_points) do
      table.insert(result, string.format("%04X", code_point))
    end
    return table.concat(result, "")
end

return text_encoder