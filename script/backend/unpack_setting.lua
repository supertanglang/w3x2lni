local command = require 'backend.command'
local lni = require 'lni'
local get_lni_map = require 'backend.get_lni_map'
local config = require 'share.config'
local lang = require 'share.lang'
local check_lni_mark = require 'share.check_lni_mark'
local root = fs.current_path()
require 'utility'
require 'filesystem'
require 'filesystem'

local root = fs.current_path()

local function output_path(path)
    if not path then
        return nil
    end
    path = fs.path(path)
    if not path:is_absolute() then
        if _W2L_DIR then
            path = fs.path(_W2L_DIR) / path
        else
            path = root:parent_path() / path
        end
    end
    return fs.absolute(path)
end

local function check_config(w2l, type, key)
    local effect  = config[type][key]
    local default = config:raw_default(type, key)
    local global  = config:raw_global(type, key)
    local map     = config:raw_map(type, key)
    local raw
    if map ~= nil then
        raw = map
    elseif global ~= nil then
        raw = global
    else
        raw = default
    end
    if effect == raw then
        return
    end
    w2l:failed(lang.script.CONFIG_INVALID_DIR:format(type, key, raw))
end

local function normalize_path(w2l, path)
    path = fs.path(path)
    if not path:is_absolute() then
        if _W2L_DIR then
            path = fs.path(_W2L_DIR) / path
        else
            path = root:parent_path() / path
        end
    end

    if path:filename():string() == '.w3x' then
        if check_lni_mark(io.load(path)) then
            return fs.absolute(path:parent_path())
        else
            w2l:failed(lang.script.UNSUPPORTED_LNI_MARK)
            return
        end
    end
    return fs.absolute(path)
end

return function (w2l, mode)
    local setting = { mode = mode }
    local output = output_path(command[3])
    local input

    if command[2] then
        input, err = normalize_path(w2l, command[2])
    elseif _W2L_MODE ~= 'CLI' then
        w2l:failed(lang.script.NO_INPUT)
        return
    else
        local err
        input, err = get_lni_map()
        if err == 'no lni' then
            w2l:failed(lang.script.NO_LNI)
            return
        elseif err == 'lni mark failed' then
            w2l:failed(lang.script.UNSUPPORTED_LNI_MARK)
            return
        end
    end

    config:open_map(input)
    for k, v in pairs(config.global) do
        setting[k] = v
    end
    if config[setting.mode] then
        for k, v in pairs(config[setting.mode]) do
            setting[k] = v
        end
    end
    setting.input = input
    setting.output = output

    check_config(w2l, 'global' ,'data_war3')
    check_config(w2l, 'global' ,'data_ui')
    check_config(w2l, 'global' ,'data_meta')
    check_config(w2l, 'global' ,'data_wes')
    return setting
end