local uci = require "luci.model.uci".cursor()
local util = require "luci.util"


function if_debug(title, value, comment)
	local is_debug = (uci:get("tsmsms", "general", "debug") == "1") and true
	local val = ""

	if (is_debug) then
		if (value and type(value) == "table") then
			val = util.serialize_json(value)
		elseif (value and type(value) == "string") then
			val = value:gsub("%c", " ")
		else
			val = value
		end
		print(title,val,"","", comment)
	end
end

-- Разделяет str (текст смс сообщение) и max_chars_length (размер кусочка смс) на кусочки текста
function split_message(str, max_chars_length)
   local lines = {}
   local line = ""
   local char_counter = 0
   local i = 1

   while i <= #str do
      local char_byte = str:byte(i)

      if char_byte <= 127 then
         line = line .. str:sub(i, i)
         i = i + 1
      elseif char_byte >= 192 and char_byte <= 223 then
         line = line .. str:sub(i, i + 1)
         i = i + 2
      elseif char_byte >= 224 and char_byte <= 239 then
         line = line .. str:sub(i, i + 2)
         i = i + 3
      elseif char_byte >= 240 and char_byte <= 247 then
         line = line .. str:sub(i, i + 3)
         i = i + 4
      end

      char_counter = char_counter + 1

      if char_counter >= max_chars_length then
         table.insert(lines, line)
         char_counter = 0
         line = ""
      end
   end

   if #line > 0 then
      table.insert(lines, line)
   end

   return lines
end

-- Читает PDU строку из AT ответа (вспомогательная функция для read sms by index)
function get_sms_pdu_data_from_at_response(at_response)
   local pdu_data = ""
   local shift = 2

   if at_response:find("OK") then
      shift = 8
   end

   for i = #at_response - shift, 1, -1 do
      if at_response:sub(i, i) == '\n' then break end
      pdu_data = at_response:sub(i, i) .. pdu_data
   end

   return pdu_data
end