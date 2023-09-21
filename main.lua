local skynet = require "skynet"
local socket = require "skynet.socket"

local mongohost = "127.0.0.1"
local mongoport = 27017
local mongoname = "xiatao01"
local mongopwd = "xiatao01"

local httpip = "0.0.0.0"
local httpport = 8001

skynet.start(function()
    --db
    local dbagent = skynet.uniqueservice("mongodb")
    --全局数据
    local globalmoudle = skynet.uniqueservice("globalmoudle")
    --游戏详情，需要落地
    local gamedata = skynet.uniqueservice("gamedata")
    --游戏list，需要落地
    local gamelist = skynet.uniqueservice("gamelist")

    --生成一堆随机的账号和密码到db
    --local ret = skynet.call(dbagent, "lua", "genaccount", {host = mongohost, port = mongoport, username = mongoname, password = mongopwd}, 10)
    --skynet.exit()

    --初始化db
    skynet.call(dbagent, "lua", "initdb", {host = mongohost, port = mongoport, username = mongoname, password = mongopwd})
    --初始化游戏详情数据
    skynet.call(gamedata, "lua", "init")
    --初始化游戏数据
    skynet.call(gamelist, "lua", "init")

    local agent = {}
    for i = 1, 3 do
        --启动20个代理服务器用于处理http请求
        agent[i] = skynet.newservice("agent")
    end

    local balance = 1
    --监听一个http端口
    local id = socket.listen(httpip, httpport)
    socket.start(id, function(id, addr)
        --当一个http请求到达的时候，把socket id分发到事先准备好的代理中去代理
        skynet.error(string.format("%s connected, agent: %08x", addr, agent[balance]))
        skynet.send(agent[balance], "lua", id)
        balance = balance + 1
        if balance > #agent then
            balance = 1
        end
    end)
end)