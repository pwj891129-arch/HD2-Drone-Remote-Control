local Cooperation = {}
function Cooperation.new(globals, state)
    local c = {participants = {}}
    function c:acquire()
        if not self.owner then self.owner = {} end
        state.input_owner, state.blocking_inputs = self.owner, true
        local ready = true
        for _, name in ipairs({'HD2StratagemHotkeys','HD2HelperAutoReload'}) do
            local peer = rawget(globals,name)
            if type(peer) == 'table' then
                assert(peer.input_api == 1 and type(peer.suspend_input) == 'function' and
                    type(peer.resume_input) == 'function','upgrade_companion:'..name)
                self.participants[peer] = true
                if peer.suspend_input(self.owner) ~= true then ready = false end
            end
        end
        return ready
    end
    function c:release()
        local ready = true
        for peer in pairs(self.participants) do
            local ok, released = pcall(peer.resume_input,self.owner)
            if not ok or released ~= true then ready = false end
        end
        if ready then
            self.participants = {}
            self.owner = nil
            state.input_owner, state.blocking_inputs = nil, false
        end
        return ready
    end
    return c
end
return Cooperation
