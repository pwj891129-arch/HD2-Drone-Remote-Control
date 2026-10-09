local Hotkey = {}
function Hotkey.new()
    local self = {}
    function self:step(input)
        if not input then self.token = nil; return end
        local fire,q = input.fire_down,input.aim_mode_down
        if type(input.binding_token) ~= 'string' or input.binding_token == '' or
            type(fire) ~= 'boolean' or type(q) ~= 'boolean' then self.token = nil; return end
        if self.token ~= input.binding_token then
            self.token,self.fire,self.q = input.binding_token,fire,q
            return
        end
        local fire_edge,q_edge = fire and not self.fire,q and not self.q
        self.fire,self.q = fire,q
        if input.active then
            if fire_edge or q_edge then return 'detonate' end
        elseif input.held and q and fire_edge then return 'arm' end
    end
    return self
end
return Hotkey
