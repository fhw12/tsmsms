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

function split_message(str, max_line_length)
   local lines = {}
   local line
   str:gsub('(%s*)(%S+)', 
      function(spc, word) 
         if not line or #line + #spc + #word > max_line_length then
            table.insert(lines, line)
            line = word
         else
            line = line..spc..word
         end
      end
   )
   table.insert(lines, line)
   return lines
end
