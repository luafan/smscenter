local print = print
local json = require "cjson.safe"
local string = string
local ipairs = ipairs
local assert = assert
local collectgarbage = collectgarbage
local socket = require "socket.core"
local os = os
local zlib = require "zlib"
local stream = require "fan.stream"
local config = require "config"
local lru = require "lru"

local utils = require "fan.utils"

local connmap = connmap
local _S = _S

local publickey_id_cache = lru.new(1024, 1024 * 1024)
local producerid_cache = lru.new(1024, 1024 * 1024)

local ctxpool = require "ctxpool"

local function get_publickeyid(ctx, publickey)
  local publickeyid = publickey_id_cache:get(publickey)
  if not publickeyid then
    local obj = ctx.sms_publickey("one", "where publickey=?", publickey)

    if not obj then
      obj = ctx.sms_publickey("new", {
          publickey = publickey
        })
    end

    publickeyid = obj.id
    publickey_id_cache:set(publickey, publickeyid, 8 + #(publickey))
  end

  return publickeyid
end

local function get_producerid(ctx, publickeyid, deviceid)
  local key = string.format("%d_%s", publickeyid, deviceid)
  local producerid = producerid_cache:get(key)
  if not producerid then
    local obj = ctx.sms_producer("one", "where publickeyid=? and deviceid=?", publickeyid, deviceid)

    if not obj then
      obj = ctx.sms_producer("new", {
          publickeyid = publickeyid,
          deviceid = deviceid,
        })
    end

    producerid = obj.id
    producerid_cache:set(key, producerid, 8 + #(key))
  end

  return producerid
end

local function update_batterylevel(ctx, map)
  local publickeyid = get_publickeyid(ctx, map.publickey)
  local producerid = get_producerid(ctx, publickeyid, map.deviceid)

  ctx:update("update sms_producer set batterylevel=? where id=?", map.batterylevel, producerid)
end

local function insert_message(ctx, map)
  local publickeyid = get_publickeyid(ctx, map.publickey)
  local producerid = get_producerid(ctx, publickeyid, map.deviceid)

  local count = 0

  for i,message in ipairs(map.list) do
    if message.msg_id then
      local obj = ctx.sms_body("one", "where producerid=? and msg_id=?", producerid, message.msg_id)
      if obj then
        for k,v in pairs(message) do
          obj[k] = v
        end
        obj:update()
      else
        message.producerid = producerid
        ctx.sms_body("new", message)
      end

      count = count + 1
    end

  end

  return count
end

local function list_message(ctx, publickey)
  local publickeyid = get_publickeyid(ctx, publickey)
  local producers = ctx.sms_producer("list", "where publickeyid=?", publickeyid)

  local list = {}
  for i,producer in ipairs(producers) do
    local msgs = ctx.sms_body("list", "where producerid=? order by id desc limit 0,20", producer.id)
    for i,v in ipairs(msgs) do
      v.deviceid = producer.deviceid
      v.batterylevel = producer.batterylevel
      table.insert(list, v)
    end
  end

  return list
end

local function onPost(req, resp)
  local starttime = utils.gettime()
  local body = req.body
  local map = json.decode(body)
  if map and map.publickey then
    if map.deviceid and map.list and type(map.list) == "table" then
      local list = map.list
      local count = 0
      if #list > 0 then
        count = ctxpool:safe(insert_message, map)
      end
      ctxpool:safe(update_batterylevel, map)
      return resp:reply(200, "OK", json.encode{status = "ok", count = count, cost = utils.gettime() - starttime})
    else
      local list = ctxpool:safe(list_message, map.publickey)
      local map = {status = "ok", list = {}}
      for i,v in ipairs(list) do
        table.insert(map.list, {
            msg_date = v.msg_date,
            msg_deskey = v.msg_deskey,
            msg_iv = v.msg_iv,
            msg_body = v.msg_body,
            msg_address = v.msg_address,
            msg_person = v.msg_person,
            deviceid = v.deviceid,
          })
      end
      table.sort(map.list, function(a,b)
        return a.msg_date > b.msg_date
      end)
      map.cost = utils.gettime() - starttime
      resp:addheader("Content-Type", "text/json; charset=UTF-8")
      return resp:reply(200, "OK", json.encode(map))
    end
  end

  return resp:reply(400, "Bad Request", "Bad Request")
end

local function onGet(req, resp)
  local starttime = utils.gettime()
  local params = req.params
  if params.publickey and params.jsonp then
    local list = ctxpool:safe(list_message, params.publickey)
    local map = {status = "ok", list = {}}
    for i,v in ipairs(list) do
      table.insert(map.list, {
          msg_date = v.msg_date,
          msg_deskey = v.msg_deskey,
          msg_iv = v.msg_iv,
          msg_body = v.msg_body,
          msg_address = v.msg_address,
          msg_person = v.msg_person,
          deviceid = v.deviceid,
        })
    end

    table.sort(map.list, function(a,b)
      return a.msg_date > b.msg_date
    end)

    map.cost = utils.gettime() - starttime
    resp:addheader("Content-Type", "application/javascript; charset=UTF-8")
    return resp:reply(200, "OK", string.format("%s(%s)", params.jsonp, json.encode(map)))
  end

  return resp:reply("400", "Bad Request", "Bad Request")
end

return {
  route = "/message",
  onGet = onGet,
  onPost = onPost,
}
