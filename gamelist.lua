local skynet = require "skynet"
local mystr = require "mystr"

--游戏list
local gamelistinfo = {}

local dbagent = nil

local function initgamelist()
    pram = {select = {data = 1}}
    local ret = skynet.call(dbagent, "lua", "opgamelist", "load", pram) or {}
    gamelistinfo = ret["data"] or {}
end

local function resetgamelist(data)
    gamelistinfo = data or {}
    skynet.error("reset gamelistinfo:%s", mystr.dump(gamelistinfo))
    argm = {update = {["$set"] = {data = data}}}
    skynet.send(dbagent, "lua", "opgamelist", "upload", argm)
    return {error = 0, msg = "ok"}
end

local function getgamelist()
    ret = {error = 0, msg = "ok", data = gamelistinfo}
    return ret
end

local cmdmap = {
    init = initgamelist,
    upload = resetgamelist,
    getall = getgamelist,
}

skynet.start(function()
    dbagent = skynet.queryservice("mongodb")
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = cmdmap[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			skynet.error(string.format("Unknown command %s", tostring(cmd)))
		end
    end)
end)