local worker_id_bits = 5
local datacenter_id_bits = 5
local sequence_bits = 12

-- 定义最大值
local max_worker_id = -1 ^ (-1 << worker_id_bits)
local max_datacenter_id = -1 ^ (-1 << datacenter_id_bits)

-- 定义初始值
local epoch = 1465876799998
local worker_id = 0
local datacenter_id = 0
local sequence = 0

-- 定义时间戳
local last_timestamp = -1

local uuid = {}

-- 定义生成ID的函数
function uuid.generate_id()
    local timestamp = os.time() * 1000 -- 转换为毫秒

    if timestamp < last_timestamp then
        error("Clock moved backwards")
    end

    if timestamp == last_timestamp then
        sequence = (sequence + 1) & (-1 ^ (-1 << sequence_bits))
        if sequence == 0 then
            timestamp = wait_next_millis(last_timestamp)
        end
    else
        sequence = 0
    end

    last_timestamp = timestamp

    local id = ((timestamp - epoch) << (worker_id_bits + sequence_bits)) |
                (datacenter_id << sequence_bits) |
                sequence

    return id
end

-- 定义等待下一个时间戳的函数
local function wait_next_millis(last_timestamp)
    local timestamp = os.time() * 1000
    while timestamp <= last_timestamp do
        timestamp = os.time() * 1000
    end
    return timestamp
end

return uuid