local Hotkey = {}
Hotkey.__index = Hotkey

function Hotkey.new()
    return setmetatable({binding_token = nil, armed = false}, Hotkey)
end

-- The runtime adapter must supply mapped actions, not fixed key codes.
function Hotkey:step(input)
    if type(input) ~= 'table' or type(input.binding_token) ~= 'string' or
       input.binding_token == '' or type(input.backpack_down) ~= 'boolean' then
        self.binding_token, self.armed = nil, false
        return nil
    end
    if input.binding_token ~= self.binding_token then
        self.binding_token, self.armed = input.binding_token, false
    end
    if not input.backpack_down then
        self.armed = true
        return nil
    end
    if not self.armed then return nil end
    self.armed = false
    if input.control_active == true or input.entry_pending == true then return 'exit' end
    if input.aim_mode_down == true and input.entry_allowed == true then
        return 'enter'
    end
    return nil
end

return Hotkey
