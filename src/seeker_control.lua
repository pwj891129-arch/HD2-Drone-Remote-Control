local Seeker = {lifetime = 30, throw_timeout = 8, quick_capture_timeout = 3, camera_hold = 0.7, entry_delay = 0.5}
function Seeker.new(reader, channel, Hotkey, report)
    local self = {hotkey = Hotkey.new()}
    function self:reset()
        self.candidate,self.after,self.armed_at,self.deadline = nil,nil,nil,nil
        self.quick_wait = nil
        self.quick_candidate,self.quick_after = nil,nil
        self.deployed_at = nil
        self.hotkey:step(nil)
    end
    function self:monitor(c,keys)
        local now,fire,q = channel:now(),channel:down(keys.fire),channel:down(keys.aim_mode)
        local quick = keys.quick_throw and channel:down(keys.quick_throw) or false
        local ticket = c.seeker_ticket
        if not ticket and not q and not self.quick_wait then
            self.candidate,self.after,self.quick_candidate,self.quick_after = nil,nil,nil,nil
            self.hotkey:step({binding_token = keys.binding_token,fire_down = fire,
                aim_mode_down = false,quick_down = quick,active = false,held = false})
            return false
        end
        if ticket then
            c.stage = 'seeker/snapshot'
            local snapshot = reader:snapshot(ticket)
            if c.active then
                c.stage = 'seeker/refresh'
                c:refresh_seeker(snapshot)
            end
            local event = self.hotkey:step({binding_token = keys.binding_token,
                fire_down = fire,aim_mode_down = q,quick_down = quick,active = c.active})
            if snapshot.detonating then
                if c.active then c:hold_seeker_camera(snapshot,'seeker_native_detonation',Seeker.camera_hold)
                else c:stop('seeker_native_detonation') end
                return true
            end
            if c.active then
                snapshot.remaining = math.max(0,self.deadline-now)
                if event == 'detonate' or now >= self.deadline then
                    c.stage = 'seeker/detonation'
                    channel:detonate(snapshot)
                    c:hold_seeker_camera(snapshot,
                        now >= self.deadline and 'seeker_time_expired' or 'seeker_manual_detonation',Seeker.camera_hold)
                    return true
                end
                return false,snapshot
            end
            -- Native throw occurs on attack release. Never steal focus or simulate
            -- a throw while the owned grenade is still attached to the actor.
            if snapshot.deployed and snapshot.motion.enabled == '\1' then
                if not self.deadline then self.deadline = now+Seeker.lifetime end
                if not self.deployed_at or now < self.deployed_at then
                    self.deployed_at = now
                    c.status = 'waiting_seeker_settle'
                    report('seeker deployed; waiting '..Seeker.entry_delay..'s before camera takeover')
                end
                if not fire and not quick and now-self.deployed_at >= Seeker.entry_delay then
                    c:enter(snapshot)
                    snapshot.remaining = math.max(0,self.deadline-now)
                    return true
                end
            else
                self.deployed_at = nil
            end
            if now-self.armed_at >= Seeker.throw_timeout then c:stop('seeker_throw_timeout') end
            return true
        end
        if not self.after or now >= self.after or q and fire and not self.hotkey.fire then
            c.stage = 'seeker/held'
            self.candidate = reader:capture()
            self.after = now+0.05
        end
        if not q then self.quick_candidate,self.quick_after = nil,nil
        elseif keys.quick_throw and not quick and not fire and (not self.quick_after or now >= self.quick_after) then
            -- Q is held before G: retain the exact attached inventory item so a
            -- fast native throw cannot disappear between press and observation.
            local ok,candidate = pcall(reader.capture,reader,true)
            self.quick_candidate = ok and candidate or nil
            self.quick_after = now+0.05
        end
        local event = self.hotkey:step({binding_token = keys.binding_token,
            fire_down = fire,aim_mode_down = q,quick_down = quick,active = false,held = self.candidate ~= nil})
        if event == 'quick_arm' then
            local cached = self.quick_candidate
            self.quick_candidate,self.quick_after = nil,nil
            if cached and not fire then
                reader:snapshot(cached)
                c.seeker_ticket,self.armed_at = cached,now
                c.status = 'waiting_seeker_throw'
                report('seeker armed: '..cached.name..'; native quick throw; exact pre-throw inventory ticket')
                return true
            end
            self.quick_wait = now+Seeker.quick_capture_timeout
            report('seeker quick throw requested; waiting up to '..Seeker.quick_capture_timeout..'s for this actor\'s attached inventory item')
        end
        if self.quick_wait then
            c.stage = 'seeker/quick_held'
            if now >= self.quick_wait then c:stop('seeker_quick_capture_timeout'); return true end
            local fresh = reader:capture(true)
            if fresh then
                c.seeker_ticket,self.armed_at,self.quick_wait = fresh,now,nil
                c.status = 'waiting_seeker_throw'
                report('seeker armed: '..fresh.name..'; native quick throw; release throw key to deploy')
            end
            return true
        end
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
