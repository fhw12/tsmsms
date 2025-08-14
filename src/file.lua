local util = require "luci.util"
local ubus = require "ubus"
local uloop = require "uloop"
local sys  = require "luci.sys"

local F = require 'posix.fcntl'
local U = require 'posix.unistd'
local D = require 'posix.dirent'

local nixio = require 'nixio'

local pdu_encoder = require "tsmsms.pdu_encoder"


require "tsmsms.util"



local file = {}
file.outgoing = "/var/spool/tsmsms/outgoing"
file.sent = "/var/spool/tsmsms/sent"
file.failed = "/var/spool/tsmsms/failed"
file.next = "" -- full path to next file
file.name = "" -- file name of current
file.pdu_text = ""
file.pdu_len = ""
file.ok_num, file.ok_sms, file.pdu_sms_text = true,true,""


function file:init(app)
	nixio.fs.mkdirr(file.outgoing)
	nixio.fs.mkdirr(file.sent)
	nixio.fs.mkdirr(file.failed)
    file.app = app
end

-- Разбивает текст на куски, кодирует в PDU,
-- и каждый кусок складывает в отдельный файл;
-- в имени файла указана длина, например:
-- 23421341_sms_1-part_[208], где 208 длина фрагмента, содержащегося в файле
function file:makePduChunks(phone_number, msg)
    local msg_parts = split_message(msg, 67)
	local total_chunks = 0
	local sms_files = {}

	for n, msg_part in ipairs(msg_parts) do
		local pdu_len, pdu_text = pdu_encoder.encode(phone_number, msg_part)

		local file_name = string.format("%s_sms_%s-part_[%s]", tostring(os.time()), tostring(n), tostring(pdu_len))
		local file_path = string.format("%s/%s", file.outgoing, file_name)

	    local f = io.open(file_path, "w")

		f:write(pdu_text)
		f:close()

		sms_files[#sms_files+1] = { path = file_path }

		total_chunks = total_chunks + 1
	end

	return total_chunks, file.outgoing, sms_files
end

function file:read_sms_file(sms_file_path)
	local pdu_length = sms_file_path:match("%[(%d+)%]")

	local f = io.open(sms_file_path, "rb")
	if not f then return '', 0 end
	local pdu_data = f:read("*a")
	f:close()

	file.pdu_text = pdu_data
	file.pdu_len = pdu_length

	return pdu_data, pdu_length
end

-- Проверяет папку. Если есть файлы, берёт первый из списка
-- и возвращает полный путь к файлу и длину содержимого
function file:findNext()
  	local pdu_len = ""
  	local filename = ""
  	local ok, files = pcall(D.dir, file.outgoing)
	if ok and #files > 2 then
		table.sort(files)
	    for _, fname in ipairs(files) do
	    	if not fname:find("[%.]+") then
	        	filename = fname
	        	break
	      	end
	    end

	    file.name = filename

	    local spos = file.name:find("%d+",20)
	    pdu_len = file.name:sub(spos,-2)
	    file.next = string.format("%s/%s", file.outgoing, file.name)
	    file.pdu_len = pdu_len

	    -- сделать здесь чтение файла и поместить текст в 
	    -- file.pdu_text
		local f = io.open(file.next, "rb") -- r read mode and b binary mode
	    if not f then return false end
	    local msg = f:read("*a") -- *a or *all reads the whole file
	    f:close()

	    file.pdu_text = msg

		return ok, file.name, pdu_len
	else
		return false
	end
end


function file:moveToSent(file_name)
	local res = nixio.fs.move(file.outgoing .. "/" .. file.name, file.sent .. "/" .. (file_name or file.name))
	if_debug("[sms.lua] moveToSent(): "..tostring(res):upper(), file.sent .. "/" .. (file_name or file.name))
end

function file:moveToFailed(file_name)
	local res = nixio.fs.move(file.outgoing .. "/" .. file.name, file.failed .. "/" .. (file_name or file.name))
	if_debug("[sms.lua] moveToFailed(): "..tostring(res):upper(), file.failed .. "/" .. (file_name or file.name))
end

function file:removeSent()

	return "file"
end

return file