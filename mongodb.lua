local skynet = require "skynet"
local mongo = require "skynet.db.mongo"
local mystr = require "mystr"
local uuid = require "uuid"

--db client
local dbclient = nil
local avatartable = nil
local gameconftable = nil

local gamedatafunc = {}
local gamelistfunc = {}

--gamedata conf_id
local Gameconfids = {
	gamedata = 1,
	gamelist = 2,
}

--批量生成用户账号
local function genaccount(args, accountnum)
    local client = mongo.client({host = args.host, port = tonumber(args.port), username = args.username, password = args.password})
	skynet.error(string.format("genaccount accountnum:%d", accountnum))
    db = client:getDB("lotterygame")
	if db then
		local t = db:getCollection("avatar")
		local docs = {}
		for i = 1, accountnum do
			local account = "user" .. i  -- 生成账号，格式为 "user1", "user2", ...
			local password = ""  -- 初始化密码
		
			-- 随机生成 8 位密码，包括大写字母、小写字母和数字
			for j = 1, 8 do
				local r = math.random(1, 3)  -- 随机生成 1 ~ 3 的数字，用于确定要生成的字符类型
					if r == 1 then  -- 生成大写字母
						password = password .. string.char(math.random(65, 90))
					elseif r == 2 then  -- 生成小写字母
						password = password .. string.char(math.random(97, 122))
					else  -- 生成数字
						password = password .. tostring(math.random(0, 9))
				end
			end

			local newid = uuid:generate_id()
			local doc = {_id = newid, account = account, password = password}
			table.insert(docs, doc)
		end
		t:batch_insert(docs)
	end

	client:disconnect()
end

--init db
local function initdb(args)
    dbclient = mongo.client({host = args.host, port = tonumber(args.port), username = args.username, password = args.password})
    if dbclient == nil then
        skynet.error(string.format("mongo connect error"))
		return
	end

	local db = dbclient:getDB("lotterygame")
	if db == nil then
        skynet.error(string.format("lotterygame db error"))
		return
	end

	avatartable = db:getCollection("avatar")
	gameconftable = db:getCollection("gameconf")
end

--clear db
local function cleardb()
	dbclient:disconnect()
end

--检查账号密码是否正确
local function checkaccount(args)
	local query = {account = args.account, password = args.password}
	local selector = {}
	local ret = avatartable:findOne(query, selector)
	if ret then
		return true
	else
		return false
	end
end

--测试账号增加
local function insertaccount(args)
	local query = {account = args.account}
	local selector = {account = args.account, password = args.password}
	local ret = avatartable:findOne(query, selector)
	if ret then
		return {error = -1, msg = "account haved exist"}
	else
		local newid = uuid:generate_id()
		local doc = {_id = newid, account = args.account, password = args.password, gmuser = 1}
		local ret = avatartable:insert(doc)
		return {error = 0, msg = "ok"}
	end
end

--测试账号删除
local function deleteaccount(args)
	local query = {account = args.account}
	local ret = avatartable:delete(query)
	return {error = 0, msg = "ok"}
end

--测试账号修改
local function updateaccount(args)
	local query = {account = args.account}
	local update = {["$set"] = {password = args.password}}
	local ret = avatartable:update(query, update)
	return {error = 0, msg = "ok"}
end

--测试账号查询
local function findaccount(args)
	local query = {account = args.account}
	local selector = {_id = 1, account = 1, password = 1}
	local ret = avatartable:findOne(query, selector)
	if ret then
		return {error = 0, msg = "ok", data = {uid = ret._id, account = ret.account, pwd = ret.password}}
	else
		return {error = -1, msg = "account no exist"}
	end
end

--加载游戏详情数据
function gamedatafunc.load(args)
	local query = {["_id"] = Gameconfids.gamedata}
	local selector = args.select
	local ret = gameconftable:findOne(query, selector)
	return ret or {}
end

--上传游戏详情数据
function gamedatafunc.upload(args)
	local query = {["_id"] = Gameconfids.gamedata}
	local update = args.update
	local ret = gameconftable:update(query, update, true)
end

--游戏详情数据操作
local function opgamedata(opcmd, ...)
	if opcmd == "load" then
		return gamedatafunc.load(...)
	elseif opcmd == "upload" then
		return gamedatafunc.upload(...)
	else
		skynet.error("opgamedata no difine opcmd:%s", opcmd)
	end
end

--加载游戏list数据
function gamelistfunc.load(args)
	local query = {["_id"] = Gameconfids.gamelist}
	local selector = args.select
	local ret = gameconftable:findOne(query, selector)
	return ret or {}
end

--上传游戏list数据
function gamelistfunc.upload(args)
	local query = {["_id"] = Gameconfids.gamelist}
	local update = args.update
	local ret = gameconftable:update(query, update, true)
end

--游戏lisy操作
local function opgamelist(opcmd, ...)
	if opcmd == "load" then
		return gamelistfunc.load(...)
	elseif opcmd == "upload" then
		return gamelistfunc.upload(...)
	else
		skynet.error("opgamelist no difine opcmd:%s", opcmd)
	end
end

local dbcmdmap = {
    initdb = initdb,
	cleardb = cleardb,
	--批量生成账号
	genaccount = genaccount,
	--校验玩家账号
	checkaccount = checkaccount,
	--游戏详情操作
	opgamedata = opgamedata,
	--游戏列表操作
	opgamelist = opgamelist,
	--用户账号增删改查
	insertaccount = insertaccount,
    deleteaccount = deleteaccount,
    updateaccount = updateaccount,
    findaccount = findaccount,
}

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = dbcmdmap[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			skynet.error(string.format("Unknown command %s", tostring(cmd)))
		end
	end)
end)
