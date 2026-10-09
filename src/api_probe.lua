local Probe = {}
local surfaces = {'Application', 'World', 'Unit', 'Camera', 'Actor', 'GameSession',
                  'Network', 'Player', 'Input', 'Keyboard', 'Mouse', 'Vector3',
                  'Quaternion', 'Matrix4x4', 'Flow', 'Ai', 'Navigation', 'PhysicsWorld', 'Physics'}

local function label(value)
    return value:gsub('[^%w_%.:/%-]', '?'):sub(1, 160)
end

function Probe.inventory(globals)
    local result = {'read_only=true; no engine functions invoked'}
    local engine = rawget(globals, 'stingray')
    if type(engine) ~= 'table' then return {'stingray=unavailable'} end
    for _, name in ipairs(surfaces) do
        local namespace = rawget(engine, name)
        local methods, count = {}, 0
        if type(namespace) == 'table' then
            -- Use raw iteration: inspecting a surface must not execute its metatable.
            for key, value in next, namespace do
                count = count + 1
                if count > 512 then break end
                if type(key) == 'string' then
                    local kind = type(value)
                    if kind == 'function' or kind == 'cdata' or kind == 'table' then
                        methods[#methods + 1] = label(key) .. ':' .. kind
                    end
                end
            end
            table.sort(methods)
            result[#result + 1] = name .. '=' .. table.concat(methods, ',')
            if count > 512 then result[#result + 1] = name .. '=truncated' end
        else
            result[#result + 1] = name .. '=unavailable'
        end
    end
    return result
end

return Probe
