local util = require "luci.util"
local ubus = require "ubus"
local uloop = require "uloop"
local sys  = require "luci.sys"

local F = require 'posix.fcntl'
local U = require 'posix.unistd'
local D = require 'posix.dirent'

local nixio = require 'nixio'


require "tsmsms.util"



local file = {}
file.outgoing = "/var/spool/tsmsms/outgoing"
file.sent = "/var/spool/tsmsms/sent"
file.failed = "/var/spool/tsmsms/failed"
file.next = "" -- full path to next file
file.name = "" -- file name of current
file.pdu_text = ""
file.pdu_len = ""
file.ok_num, ok_sms, pdu_sms_text = true,true,""


function file:init(app, sms)
	nixio.fs.mkdirr(file.outgoing)
	nixio.fs.mkdirr(file.sent)
	nixio.fs.mkdirr(file.failed)
    file.app = app
    file.sms = sms
end

-- Разбивает текст на куски, кодирует в PDU,
-- и каждый кусок складывает в отдельный файл;
-- в имени файла указана длина, например:
-- 23421341_sms_1-part_[208], где 208 длина фрагмента, содержащегося в файле
function file:makePduChunks(phone, msg)
	local pdu_len = 0
	local pdu_text = ""
	local total_chunks = 0

	local filename, fpath = "", ""
    local parts = split_message(msg, 67)

	for n, part in ipairs(parts) do
	    pdu_len, pdu_text = EncoderPDU(phone, part)

		filename = string.format("%s_sms_%s-part_[%s]", tostring(os.time()), tostring(n), tostring(pdu_len))

		fpath = string.format("%s/%s", file.outgoing, filename)

		print("PATH: ", fpath)

	    local f = io.open(fpath, "w")
		f:write(pdu_text)
		f:close()
		total_chunks = total_chunks + 1
	end

	return total_chunks, file.outgoing
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


function file:moveToSent()
	local res = nixio.fs.move(file.outgoing .. "/" .. file.name, file.sent .. "/" .. file.name)
	if_debug("[sms.lua] moveToSent(): "..tostring(res):upper(), file.sent .. "/" .. file.name)
end

function file:moveToFailed()

	return "file"
end

function file:removeSent()

	return "file"
end

return file