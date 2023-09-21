local skynet = require "skynet"
local mystr = require "mystr"

--游戏详情数据
local gameinfo = {}

local dbagent = nil

local function initgamedata()
    pram = {select = {data = 1}}
    local ret = skynet.call(dbagent, "lua", "opgamedata", "load", pram) or {}
    gameinfo = ret["data"] or {}
end

local function resetgameinfo(data)
    gameinfo = data or {}
    skynet.error("reset gamedata:%s", mystr.dump(gameinfo))
    argm = {update = {["$set"] = {data = data}}}
    skynet.send(dbagent, "lua", "opgamedata", "upload", argm)
    return {error = 0, msg = "ok"}
end

local function getgameinfo()
    ret = {error = 0, msg = "ok", data = gameinfo}
    return ret
end

local cmdmap = {
    init = initgamedata,
    upload = resetgameinfo,
    getall = getgameinfo,
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