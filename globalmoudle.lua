local skynet = require "skynet"
local mystr = require "mystr"

--玩家 uid->userinfo
local usermap = {}
--管理员auth
local rootauth = "lotteryauth"

local function checktoken(uid, token)
    if uid == 0 and token == rootauth then
        return true, 0
    elseif usermap[uid] ~= nil and usermap[uid]["token"] == token then
        return true, 3
    end

    return false
end

local function updateuserinfo(uid, info)
    usermap[uid] = info
end

local function updaterootauth(auth)
    rootauth = auth
end

local cmdmap = {
    checktoken = checktoken,
    updateuserinfo = updateuserinfo,
    updaterootauth = updaterootauth,
}

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = cmdmap[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			skynet.error(string.format("Unknown command %s", tostring(cmd)))
		end
    end)
end)