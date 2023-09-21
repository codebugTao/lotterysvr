local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local json = require "json"
local crypt = require "skynet.crypt"
local mystr = require "mystr"
local const = require "constdef"

--用于加密 Token 的密钥
local secret = "mysecret"
--是否需要校验身份，开发环境关闭认证
--local isauth = false
local isauth = true
local rootaccount = "lottery"
local rootpwd = "lottery"

local dbagent = nil
local globalmoudle = nil
local gamedata = nil
local gamelist = nil

--返回数据
local function response(id, ...)
    local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
    if not ok then
        skynet.error(string.format("fd:%d, err:%s", id, err))
    end
end

--生成token
local function gentoken(username)
    -- 当前时间戳
    local timestamp = tostring(os.time())
    -- 组合成需要加密的数据
    local data = username .. ":" .. timestamp
    return "abc"
    -- 使用 DES 加密并 Base64 编码
    --return crypt.base64encode(crypt.desencode(secret, data))
end

local function checkaccount(account, pwd)
    local ret = skynet.call(dbagent, "lua", "checkaccount", {account = account, password = pwd})
    return ret
end

local function checkrootlevel(level)
    return level <= const.root
end

local function getgamelist(level)
    local ret = skynet.call(gamelist, "lua", "getall")
    return ret
end

local function getgamedata(level)
    local ret = skynet.call(gamedata, "lua", "getall")
    return ret
end

local function draw(level)
    -- 设定随机种子
    math.randomseed(os.time())
    local rewardid = math.random(1, 100)
    return {rewardid = rewardid}
end

local function opgamedata(level, body)
    if not checkrootlevel(level) then
        return {error = -1, msg = "Insufficient permissions"}
    end
    body = json.decode(body)
    opcmd = body["opcmd"]
    local ret = skynet.call(gamedata, "lua", opcmd, body.data)
    return ret
end

local function opgamelist(level, body)
    if not checkrootlevel(level) then
        return {error = -1, msg = "Insufficient permissions"}
    end
    body = json.decode(body)
    opcmd = body["opcmd"]
    local ret = skynet.call(gamelist, "lua", opcmd, body.data)
    return ret
end

local function insertaccount(level, body)
    if not checkrootlevel(level) then
        return {error = -1, msg = "Insufficient permissions"}
    end
    body = json.decode(body)
    if body.account == nil or body.pwd == nil then
        return {error = -1, msg = "account or pwd is none"}
    end
    local ret = skynet.call(dbagent, "lua", "insertaccount", {account = body.account, password = body.pwd})
    return ret
end

local function deleteaccount(level, body)
    if not checkrootlevel(level) then
        return {error = -1, msg = "Insufficient permissions"}
    end
    body = json.decode(body)
    if body.account == nil then
        return {error = -1, msg = "account is none"}
    end
    local ret = skynet.call(dbagent, "lua", "deleteaccount", {account = body.account})
    return ret
end

local function updateaccount(level, body)
    if not checkrootlevel(level) then
        return {error = -1, msg = "Insufficient permissions"}
    end
    body = json.decode(body)
    if body.account == nil or body.pwd == nil then
        return {error = -1, msg = "account or pwd is none"}
    end
    local ret = skynet.call(dbagent, "lua", "updateaccount", {account = body.account, password = body.pwd})
    return ret
end

local function findaccount(level, body)
    if not checkrootlevel(level) then
        return {error = -1, msg = "Insufficient permissions"}
    end
    body = json.decode(body)
    if body.account == nil then
        return {error = -1, msg = "account is none"}
    end
    local ret = skynet.call(dbagent, "lua", "findaccount", {account = body.account})
    return ret
end

local httpgetcmds = {
    ["/getgamelist"] = getgamelist,
    ["/getgamedata"] = getgamedata,
    ["/draw"] = draw,
    ["/operategamedata"] = opgamedata,
    ["/operategamelist"] = opgamelist,
    --用户账号增删改查
    ["/insertaccount"] = insertaccount,
    ["/deleteaccount"] = deleteaccount,
    ["/updateaccount"] = updateaccount,
    ["/findaccount"] = findaccount,
}

skynet.start(function()
    dbagent = skynet.queryservice("mongodb")
    globalmoudle = skynet.queryservice("globalmoudle")
    gamedata = skynet.queryservice("gamedata")
    gamelist = skynet.queryservice("gamelist")
    skynet.dispatch("lua", function(session, source, id)
        --开始接收一个socket
        socket.start(id)
        --limit request body size to 8192 (you can pass nil to unlimt)
        --一般的业务不需要处理大量上行数据，为了防止攻击，做一个8K限制。这个限制可以去掉
        local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id))
        if code then
            --如果协议有错误，就回应一个错误码code
            if code ~= 200 then
                response(id, code, "")
            else
                skynet.error(string.format("agent:%d, method:%s, url:%s, header:%s, body:%s", id, method, url, mystr.dump(header), mystr.dump(body)))
                if method == "POST" and url == "/login" then
                    --用户登录请求
                    body = json.decode(body)
                    if body["account"] == nil or body["pwd"] == nil then
                        response(id, 400, "")
                    else
                        local ret = checkaccount(body["account"], body["pwd"])
                        if ret then
                            local token = gentoken(body["account"])
                            local uid = ret["_id"]
                            local resbody = json.encode({uid = uid, token = token})
                            local info = {token = token}
                            skynet.call(globalmoudle, "lua", "updateuserinfo", uid, info)
                            response(id, 200, resbody)
                        else
                            response(id, 401, "")
                        end
                    end
                elseif method == "POST" and url == "/rootlogin" then
                    --管理员登录
                    body = json.decode(body)
                    if body["account"] == rootaccount or body["pwd"] == rootpwd then
                        local token = gentoken(body["account"])
                        local resbody = json.encode({token = token})
                        skynet.call(globalmoudle, "lua", "updaterootauth", token)
                        response(id, 200, resbody)
                    else
                        response(id, 401, "")
                    end
                else
                    local istruetoken = true
                    local level = const.root
                    if isauth then
                        istruetoken, level = skynet.call(globalmoudle, "lua", "checktoken", tonumber(header["uid"]), header["authorization"])
                    end
                    if istruetoken then
                        local f = httpgetcmds[url]
                        if f then
                            local resbody = json.encode(f(level, body))
                            skynet.error(string.format("resbody:%s", mystr.dump(resbody)))
                            response(id, 200, resbody)
                        else
                            response(id, 401, "")
                        end
                    else
                        response(id, 401, "")
                    end
                end
            end
        else
            --如果抛出的异常是sockethelper.socket_error表示是客户端网络断开了
            if url == sockethelper.socket_error then
                skynet.error("socket closed")
            else
                skynet.error(url)
            end
            --socket.close(id)
        end
        --主动断开连接,暂采用短连接
        socket.close(id)
    end)
end)