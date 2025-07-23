
local util = require "luci.util"
local ubus = require "ubus"
local uloop = require "uloop"
local sys  = require "luci.sys"

local F = require 'posix.fcntl'
local U = require 'posix.unistd'

require "tsmsms.util"


sms = {}
sms.status = {
	inprogress = false,
	file = ""				-- путь к файлу, обрабатываемому на данной итерации
}

sms.body = {
	text = "",				-- текущий текст смс-сообщения
	phone = "",				-- телефон получателя
	pdu_len = 0,
	pdu_text = ""
}


function sms:init(app, file)
    sms.app = app
    sms.file = file
    return sms
end


function sms:goPDU()
	local ubus_response = util.ubus("tsmodem.driver", "automation", {})
	if_debug("[sms.lua] goPDU()", "AT+CMGF=0", string.format("Automation mode: [%s]", tostring(ubus_response["mode"])))
	ubus_response = util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=0" })
	print('>>> ubus_response (sms:goPDU): ', ubus_response)
	for key, value in pairs(ubus_response) do
		print(key, value)
	end
	print('>>> ubus_response end\n')
end

function sms:goTEXT()
	if_debug("[sms.lua] goTEXT()", "AT+CMGF=1")
	local ubus_response = util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=1" })
	print('>>> ubus_response (sms:goTEXT): ', ubus_response)
	for key, value in pairs(ubus_response) do
		print(key, value)
	end
	print('>>> ubus_response end\n')
end

function sms:setPduLength()
	local pdu_len = sms.file.pdu_len
	local ubus_response = util.ubus("tsmodem.driver", "automation", {})
	if_debug("[sms.lua] setPduLength()", pdu_len, string.format("Automation mode: [%s]", tostring(ubus_response["mode"])))
	util.ubus("tsmodem.driver", "send_at", { ["command"] = string.format("AT+CMGS=%s", pdu_len) })
	print('>>> ubus_response (sms:setPduLength): ', ubus_response)
	for key, value in pairs(ubus_response) do
		print(key, value)
	end
	print('>>> ubus_response end\n')
end

function sms:sendPduText(pdu)
	local pdu_text = sms.file.pdu_text
	local ubus_response = util.ubus("tsmodem.driver", "automation", {})
	if_debug("[sms.lua] sendPduText()", pdu_text, string.format("Automation mode: [%s]", tostring(ubus_response["mode"])))
	util.ubus("tsmodem.driver", "send_at", { ["command"] = string.format("%s\26", pdu_text) })
	print('>>> ubus_response (sms:sendPduText): ', ubus_response)
	for key, value in pairs(ubus_response) do
		print(key, value)
	end
	print('>>> ubus_response end\n')
end



return sms