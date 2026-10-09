local Seeker = {lifetime = 30, throw_timeout = 8}
function Seeker.new(reader, channel, Hotkey, report)
    local self = {hotkey = Hotkey.new()}
    function self:reset()
        self.candidate,self.after,self.armed_at,self.deadline = nil,nil,nil,nil
        self.hotkey:step(nil)
    end
    function self:monitor(c,keys)
        local now,fire,q = channel:now(),channel:down(keys.fire),channel:down(keys.aim_mode)
        local ticket = c.seeker_ticket
        if ticket then
            c.stage = 'seeker/snapshot'
            local snapshot = reader:snapshot(ticket)
            local event = self.hotkey:step({binding_token = keys.binding_token,
                fire_down = fire,aim_mode_down = q,active = c.active})
            if snapshot.detonating then c:stop('seeker_native_detonation'); return true end
            if c.active then
                snapshot.remaining = math.max(0,self.deadline-now)
                if event == 'detonate' or now >= self.deadline then
                    c.stage = 'seeker/detonation'
                    channel:detonate(snapshot)
                    c:stop(now >= self.deadline and 'seeker_time_expired' or 'seeker_manual_detonation')
                    return true
                end
                return false,snapshot
            end
            -- Native throw occurs on attack release. Never steal focus or simulate
            -- a throw while the owned grenade is still attached to the actor.
            if snapshot.deployed and snapshot.motion.enabled == '\1' then
                if not self.deadline then self.deadline = now+Seeker.lifetime end
                if not fire then
                    c:enter(snapshot)
                    snapshot.remaining = math.max(0,self.deadline-now)
                    return true
                end
            end
            if now-self.armed_at >= Seeker.throw_timeout then c:stop('seeker_throw_timeout') end
            return true
        end
        if not self.after or now >= self.after or q and fire and not self.hotkey.fire then
            c.stage = 'seeker/held'
            self.candidate = reader:capture()
            self.after = now+0.05
        end
        local event = self.hotkey:step({binding_token = keys.binding_token,
            fire_down = fire,aim_mode_down = q,active = false,held = self.candidate ~= nil})
        if event == 'arm' then
            -- Recheck at the exact press, not against a stale held-item cache.
            local fresh = reader:capture()
            if fresh and self.candidate and fresh.identity == self.candidate.identity and
                fresh.actor_identity == self.candidate.actor_identity then
                c.seeker_ticket,self.armed_at = fresh,now
                c.status = 'waiting_seeker_throw'
                report('seeker armed: '..fresh.name..'; release attack to throw; native throw unchanged')
                return true
            end
        end
        return self.candidate ~= nil
    end
    return self
end
return Seeker
