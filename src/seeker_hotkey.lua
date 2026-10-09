local Hotkey = {}
function Hotkey.new()
    local self = {}
    function self:step(input)
        if not input then self.token = nil; return end
        local fire,q,quick = input.fire_down,input.aim_mode_down,input.quick_down or false
        if type(input.binding_token) ~= 'string' or input.binding_token == '' or
            type(fire) ~= 'boolean' or type(q) ~= 'boolean' or type(quick) ~= 'boolean' then self.token = nil; return end
        if self.token ~= input.binding_token then
            self.token,self.fire,self.q,self.quick = input.binding_token,fire,q,quick
            return
        end
        local fire_edge,q_edge,quick_edge = fire and not self.fire,q and not self.q,quick and not self.quick
        self.fire,self.q,self.quick = fire,q,quick
        if input.active then
            if fire_edge or q_edge then return 'detonate' end
        elseif q and quick_edge then return 'quick_arm'
        elseif input.held and q and fire_edge then return 'arm' end
    end
    return self
end
return Hotkey
