(function()
    local exepath = package.cpath:sub(1, (package.cpath:find(';') or 0)-6)
    package.path = package.path .. ';' .. exepath .. '..\\script\\?.lua'
end)()

require 'filesystem'
require 'utility'
local w2l  = require 'w3x2lni'
local uni      = require 'ffi.unicode'
local archive = require 'archive'
local order_prebuilt = require 'order.prebuilt'
local default2lni = require 'prebuilt.default2lni'
local prebuilt_metadata = require 'prebuilt.prebuilt_metadata'
local prebuilt_keydata = require 'prebuilt.prebuilt_keydata'
local prebuilt_search = require 'prebuilt.prebuilt_search'
local prebuilt_miscnames = require 'prebuilt.prebuilt_miscnames'
local w3xparser = require 'w3xparser'
local slk = w3xparser.slk

w2l:initialize()

function message(...)
    if select(1, ...) == '-progress' then
        return
    end
    local tbl = {...}
    local count = select('#', ...)
    for i = 1, count do
        tbl[i] = uni.u2a(tostring(tbl[i])):gsub('[\r\n]', ' ')
    end
    print(table.concat(tbl, ' '))
end

local function prebuilt_codemapped(w2l)
    local template = w2l:parse_slk(io.load(w2l.agent / w2l.info.slk.ability[1]) or io.load(w2l.mpq / w2l.info.slk.ability[1]))
    local t = {}
    for id, d in pairs(template) do
        t[id] = d.code
    end
    local f = {}
    for k, v in pairs(t) do
        f[#f+1] = ('%s = %s'):format(k, v)
    end
    table.sort(f)
    table.insert(f, 1, '[root]')
    io.save(w2l.defined / 'codemapped.ini', table.concat(f, '\r\n'))
end

local function prebuilt_typedefine(w2l)
    local uniteditordata = w2l:parse_txt(io.load(w2l.meta / 'uniteditordata.txt'))
    local f = {}
    f[#f+1] = ('%s = %s'):format('int', 0)
    f[#f+1] = ('%s = %s'):format('bool', 0)
    f[#f+1] = ('%s = %s'):format('real', 1)
    f[#f+1] = ('%s = %s'):format('unreal', 2)
    for key, data in pairs(uniteditordata) do
        local value = data['00'][1]
        local tp
        if tonumber(value) then
            tp = 0
        else
            tp = 3
        end
        f[#f+1] = ('%s = %s'):format(key, tp)
    end
    table.sort(f)
    table.insert(f, 1, '[root]')
    io.save(w2l.defined / 'typedefine.ini', table.concat(f, '\r\n'))
end

local abilitybuffdata = {
    {'alias',   'code', 'comments', 'isEffect', 'version', 'useInEditor', 'sort', 'race' , 'InBeta'},
    ['Bdbl'] = {'Bdbl', 'YDWE'    , 0         , 1        , 1            , 'hero', 'human', 1       },
    ['Bdbm'] = {'Bdbm', 'YDWE'    , 0         , 1        , 1            , 'hero', 'human', 1       },
    ['BHtb'] = {'BHtb', 'YDWE'    , 0         , 1        , 1            , 'unit', 'other', 1       },
    ['Bsta'] = {'Bsta', 'YDWE'    , 0         , 1        , 1            , 'unit', 'orc'  , 1       },
    ['Bdbb'] = {'Bdbb', 'YDWE'    , 0         , 1        , 1            , 'hero', 'human', 1       },
    ['BIpb'] = {'BIpb', 'YDWE'    , 0         , 1        , 1            , 'item', 'other', 1       },
    ['BIpd'] = {'BIpd', 'YDWE'    , 0         , 1        , 1            , 'item', 'other', 1       },
    ['Btlf'] = {'Btlf', 'YDWE'    , 0         , 1        , 1            , 'unit', 'other', 1       },
}

local function merge_slk(t, fix)
    for k, v in pairs(fix) do
        if k ~= 1 then
            t[k] = {}
            for i, key in ipairs(fix[1]) do
                if i ~= 1 then
                    t[k][key] = v[i-1]
                end
            end
        end
    end
end

local function build_slk()
	local hook
	function w2l:parse_slk(buf)
		if hook then
			local r = slk(buf)
			hook(r)
			hook = nil
			return r
		end
		return slk(buf)
	end
	local ar1 = archive(w2l.agent)
    local ar2 = archive(w2l.mpq)
	local slk = w2l:frontend_slk(function(name)
		if name == 'units\\abilitybuffdata.slk' then
			function hook(t)
                merge_slk(t, abilitybuffdata)
			end
		end
		return ar1:get(name) or ar2:get(name)
	end)
	w2l:frontend_misc(ar1:get('war3mapmisc.txt') or ar2:get('war3mapmisc.txt'), slk)
	return slk
end

local function set_config()
    local config = w2l.config
    -- 转换后的目标格式(lni, obj, slk)
    config.target_format = 'lni'
    -- 是否分析slk文件
    config.read_slk = true
    -- 分析slk时寻找id最优解的次数,0表示无限,寻找次数越多速度越慢
    config.find_id_times = 0
    -- 移除与模板完全相同的数据
    config.remove_same = false
    -- 移除超出等级的数据
    config.remove_exceeds_level = true
    -- 移除只在WE使用的文件
    config.remove_we_only = false
    -- 移除没有引用的对象
    config.remove_unuse_object = false
    -- mdx压缩
    config.mdx_squf = false
    -- 转换为地图还是目录(mpq, dir)
    config.target_storage = 'dir'
end

local function dofile(version, template)
    message('==================')
    message(('       %s      '):format(version))
    message('==================')

    w2l.config.version = version
    w2l:update()
    fs.create_directories(w2l.default)

	local slk = build_slk()
    message('正在生成default')
    for _, ttype in ipairs {'ability', 'buff', 'unit', 'item', 'upgrade', 'doodad', 'destructable', 'misc'} do
        local data = slk[ttype]
        io.save(w2l.default / (ttype .. '.ini'), default2lni(data))
    end
    io.save(w2l.default / 'txt.ini', default2lni(slk.txt))
    
    if template then
        message('正在生成template')
        for _, ttype in ipairs {'ability', 'buff', 'unit', 'item', 'upgrade', 'doodad', 'destructable', 'misc'} do
            local data = w2l:frontend_merge(ttype, slk[ttype], {})
            io.save(w2l.template / (ttype .. '.ini'), w2l:backend_lni(ttype, data))
        end
        io.save(w2l.template / 'txt.ini', w2l:backend_txtlni(slk.txt))
    end
end

local function main()
    set_config()

    fs.create_directories(w2l.template)
    fs.create_directories(w2l.defined)

    prebuilt_codemapped(w2l)
    prebuilt_typedefine(w2l)
    prebuilt_miscnames(w2l)
    prebuilt_metadata(w2l)
    prebuilt_keydata(w2l)
    prebuilt_search(w2l)

    dofile('Melee')
    dofile('Custom', 'template')

    -- 生成技能命令映射
    --local skill_data = w2l:parse_lni(io.load(w2l.template / 'ability.ini'))
    --local order_list = order_prebuilt(skill_data)
    --io.save(w2l.root / 'script' / 'order' / 'order_list.lua', order_list)

    message('[完毕]: 用时 ' .. os.clock() .. ' 秒') 
end

main()
