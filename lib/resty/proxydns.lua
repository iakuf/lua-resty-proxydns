local resolver = require "resty.dns.resolver"
local server = require "resty.dns.server"
local cjson = require "cjson"
local cache = ngx.shared.dns_cache
local _M = {}
local dns
local config
local target_ip
function _M:config(dns)
    config = dns or {
        nameservers = {"114.114.114.114"},
        retrans = 3,
        timeout = 1500,
    }
end

function _M:redirect_all(ip) 
    target_ip = ip
end

function _M:init_custom_domains(filename)
    local file, err = io.open(filename, "r")
    if not file then
        ngx.log(ngx.ERR, "failed to open custom domains file: ", err)
        return
    end

    for line in file:lines() do
        local parts = {}
        for part in line:gmatch("%S+") do
            table.insert(parts, part)
        end
        if #parts == 2 then
            local qname = parts[1]
            local address = parts[2]
            local cache_key = qname .. ":1" -- A 记录 
            local answers = { {
                    ttl = 60,
                    type = 1,
                    section = 1,
                    address =  address,
                    name = qname
                } }
            local cache_data = {
                answers = answers,
                timestamp = ngx.time(),
                type = 'custom',
            }
            cache:set(cache_key, cjson.encode(cache_data))
        end
    end
    file:close()
end

local function receive_data()
    local data, err = ngx.ctx.socket:receive()
    if not data then
        ngx.log(ngx.ERR, "failed to receive data: ", err)
        return nil
    end
    return data
end

local function process_request(data)
    dns = server:new();
    local request, err = dns:decode_request(data)

    if not request then
        ngx.log(ngx.ERR, "failed to decode request: ", err)
        return nil, nil, "failed to decode request"
    end

    return request.questions[1].qname, request.questions[1].qtype
end

local function set_cache_answers(cache_key, answers)
    -- data 的结构, 是 dns client 取回来的 answers
    --  [
    --      {"ttl":596,"section":1,"type":5,"cname":"www.a.shifen.com","name":"www.baidu.com","class":1},
    --      {"ttl":122,"section":1,"type":1,"address":"183.2.172.185","name":"www.a.shifen.com","class":1},
    --      {"ttl":122,"section":1,"type":1,"address":"183.2.172.42","name":"www.a.shifen.com","class":1}
    --  ]
    local ttl = answers[1] and answers[1].ttl or 300 
    local cache_data = {
        answers = answers,
        timestamp = ngx.time(), -- -- 记录当前时间作为 timestamp
    }
    cache:set(cache_key, cjson.encode(cache_data), ttl)
end

local function create_cache_answers(qname, qtype) 
    ngx.log(ngx.ERR, "--------- create_cache")
    if target_ip and target_ip ~= "" then
        ngx.log(ngx.ERR, "---------")
        dns:create_a_answer(qname, 60, target_ip)
        return true 
    end
    local cache_key = qname .. ":" .. qtype
    local cache_data = cache:get(cache_key)
    if cache_data then
        local data = cjson.decode(cache_data)
        local answers = data.answers
        for _, ans in ipairs(answers) do
            if not data.type then -- 仅在 type 不存在时计算剩余 TTL
                local remaining_ttl = ans.ttl - (ngx.time() - data.timestamp)  -- 使用 timestamp 计算剩余 TTL
                ans.ttl = remaining_ttl > 0 and remaining_ttl or 0
            end

            if ans.type == server.TYPE_A then
                dns:create_a_answer(ans.name, ans.ttl, ans.address)
            elseif ans.type == server.TYPE_CNAME then
                dns:create_cname_answer(ans.name, ans.ttl, ans.cname)
            end
        end
        return true
    end
    return false
end

local function create_answers(answers)
    for _, ans in ipairs(answers) do
        if ans.type == server.TYPE_A then
            dns:create_a_answer(ans.name, ans.ttl, ans.address)
        elseif ans.type == server.TYPE_CNAME then
            dns:create_cname_answer(ans.name, ans.ttl, ans.cname)
        end
    end
end

local function resolve_dns(qname, qtype)
    -- qname == 需要查询的域名, 例如 test.com
    -- qtype == 1 为 A 记录
    -- step 本地查询 cache 没有过期使用本地的数据
    local result = create_cache_answers(qname, qtype)
    if result then 
        return 
    end

    -- 查询使用远程的数据
    --  nameservers = {"114.114.114.114"}, 
    --  retrans = 3, 
    --  timeout = 1500,
    local r, err = resolver:new(config)

    if not r then
        ngx.log(ngx.ERR, "failed to instantiate the resolver: ", err)
        return nil
    end


    local answers, err = r:query(qname, { qtype = qtype })
    if not answers then
        ngx.log(ngx.ERR, "failed to query the DNS server: ", err)
        return nil
    end

    local cache_key = qname .. ":" .. qtype
    set_cache_answers(cache_key, answers)
    create_answers(answers)
end

local function send_response(response)
    local bytes, err = ngx.ctx.socket:send(response)
    if not bytes then
        ngx.log(ngx.ERR, "failed to send response: ", err)
    end
end



function _M:run()
    ngx.ctx.socket = ngx.req.socket()
    if not ngx.ctx.socket  then
        ngx.log(ngx.ERR, "failed to get the request socket: ")
        return nil
    end
    local data = receive_data()
    if data then
        -- setp 1 查询有没有 request 的解析
        local qname, qtype, err = process_request(data)
        if err == nil  then
            resolve_dns(qname, qtype)
            local response = dns:encode_response()
            send_response(response)
        end

    end
end

return _M

