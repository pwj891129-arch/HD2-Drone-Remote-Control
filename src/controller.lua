local Controller = {}
function Controller.new(channel, reader, engine, B, Lease, Flight, Hotkey, report, cooperation, aim, options, pose, avoidance)
    local c = {active = false, status = 'idle', hotkey = Hotkey.new(), pending_cleanup = false}
    local zero = B.u32(0)
    function c:reset_inputs(preserve_seeker)
        self.hotkey:step(nil)
        if self.seeker and not self.seeker_ticket and not preserve_seeker then self.seeker:reset() end
        if not self.pack_lease and not self.input_lease then self.keys = nil end
    end
    function c:stop(reason)
        self.active = false
        if avoidance then avoidance:clear() end
        self.pending_cleanup = false
        self.pending = nil
        self.aftermath = nil
        self.seeker_ticket = nil
        if self.seeker then self.seeker:reset() end
        if self.pulse then
            if channel:key(self.pulse.key,false) then self.pulse = nil
            else self.pending_cleanup = true; report('backpack input release pending') end
        end
        if self.session then
            local session = self.session
            -- Reallocation can copy our paused flags into new buffers. Resolve the
            -- same full ownership key before restoring those bytes, never a new drone.
            local fresh_ok, fresh = pcall(function()
                local candidate = session.context.kind == 'seeker' and
                    reader:seeker_snapshot(session.context.ticket) or reader:snapshot()
                assert(session.ownership_key and candidate.ownership_key == session.ownership_key and
                    candidate.unit_valid(), 'cleanup_owner_changed')
                return candidate
            end)
            if fresh_ok then
                for _, pair in ipairs({{session.behavior,fresh.brain},{session.motion,fresh.motion},
                    {session.movement,fresh.movement}}) do
                    if pair[1] then
                        pcall(session.lease.rebind,session.lease,pair[1],pair[2].address,pair[2].valid)
                    end
                end
                if aim and aim.rebind then pcall(aim.rebind,aim,fresh) end
                session.context = fresh
            end
            local ok, why = pcall(function()
                if session.context.kind ~= 'seeker' and session.context.fire_valid() then channel:fire(session.context,false) end
            end)
            if not ok then report('fire cleanup: '..tostring(why)) end
            if aim then
                local restored, why = pcall(aim.clear,aim)
                if not restored then self.pending_cleanup = true; report('aim cleanup: '..tostring(why)) end
            end
            if pose then
                local restored, why = pcall(pose.clear,pose)
                if not restored then self.pending_cleanup = true; report('rotation cleanup: '..tostring(why)) end
            end
            if session.camera_lease then
                self.pending_cleanup = not session.camera_lease:release() or self.pending_cleanup
            end
            self.pending_cleanup = not session.lease:release() or self.pending_cleanup
            if not self.pending_cleanup then self.session = nil end
        end
        if self.pack_lease then
            self.pending_cleanup = not self.pack_lease:release() or self.pending_cleanup
            if #self.pack_lease.items == 0 then self.pack_lease = nil end
        end
        if self.input_lease then
            self.pending_cleanup = not self.input_lease:release() or self.pending_cleanup
            if #self.input_lease.items == 0 then
                self.input_lease = nil
                if self.keys then self.keys.inputs_suppressed = false end
            end
        end
        local ok, why = pcall(engine.clear,engine)
        if not ok then self.pending_cleanup = true; report('engine cleanup: '..tostring(why)) end
        if not self.pending_cleanup and cooperation then
            self.pending_cleanup = not cooperation:release()
        end
        self.status = reason
        self:reset_inputs()
        report('exit: '..reason)
    end
    function c:arm_backpack(keys)
        if self.pack_lease then return end
        self.pack_lease = Lease.new(channel)
        for _, item in ipairs(keys.pack_entries) do
            if item[2] ~= zero then self.pack_lease:claim(item[1],item[2],zero,item[3] or keys.valid) end
        end
    end
    function c:arm_inputs(keys)
        assert(not self.input_lease and keys.valid() and type(keys.input_entries) == 'table' and
            #keys.input_entries > 0, 'player_input_bindings_unavailable')
        self.input_lease = Lease.new(channel)
        keys.inputs_suppressed = true
        for _, item in ipairs(keys.input_entries) do
            if item[2] ~= zero then self.input_lease:claim(item[1],item[2],zero,item[3] or keys.valid) end
        end
        report('player gameplay bindings captured: '..#self.input_lease.items)
    end
    function c:begin(snapshot)
        self.stage = 'entry/recall_prepare'
        assert(not self.pending_cleanup and snapshot.unit_valid() and snapshot.fire_valid(), 'entry_not_ready')
        assert(reader:word(snapshot.brain.address) == snapshot.behavior_kind, 'drone_behavior_changed')
        if cooperation then assert(cooperation:acquire(),'companion_input_release_pending') end
        engine:observe(snapshot)
        self.pending = {token = snapshot.token, binding_token = self.keys.binding_token,
            phase = 'waiting_keys', deadline = channel:now()+8}
        self.status = 'waiting_keys'
        report('entry requested; release aim-mode and backpack keys; recall before control')
    end
    function c:backpack_pulse(keys, phase)
        assert(not self.pulse and not self.pack_lease and keys.valid() and
            not channel:down(keys.aim_mode) and not channel:down(keys.backpack), 'backpack_input_not_ready')
        self.pulse = {key = keys.backpack, until_time = channel:now()+0.1}
        self.pending.phase,self.pending.deadline,self.pending.stable = phase,channel:now()+8,nil
        assert(channel:key(keys.backpack,true), 'backpack_input_failed')
        self.status = phase
        report('backpack command: '..phase)
    end
    function c:prepare_tick(snapshot, keys, aim_mode_down, backpack_down)
        local pending,now = self.pending,channel:now()
        self.stage = 'entry/'..pending.phase
        assert(keys.binding_token == pending.binding_token and snapshot.token == pending.token and snapshot.unit_valid() and
            reader:word(snapshot.brain.address) == snapshot.behavior_kind, 'entry_connection_changed')
        if now >= pending.deadline then self:stop('entry_timeout:'..pending.phase); return end
        if pending.phase == 'waiting_keys' then
            if aim_mode_down or backpack_down then return end
            if self.pack_lease then
                assert(self.pack_lease:release(),'backpack_binding_restore_pending')
                self.pack_lease = nil
            end
            pending.phase,pending.after = 'check_dock',now+0.1
            return
        end
        if self.pulse or aim_mode_down or backpack_down or pending.after and now < pending.after then return end
        local observed = engine:observe(snapshot)
        local observation = pending.phase..':'..tostring(observed.docked)..':'..tostring(observed.airborne)..':'..
            tostring(observed.free)
        if observation ~= pending.observation then
            pending.observation = observation
            report('preparation: phase='..pending.phase..'; docked='..tostring(observed.docked)..
                '; airborne='..tostring(observed.airborne)..'; free='..tostring(observed.free)..
                string.format('; distance=%.2fm',observed.distance)..'; parent_ref='..tostring(observed.parent_ref))
        end
        if pending.phase == 'check_dock' and observed.airborne then
            self:backpack_pulse(keys,'recalling'); return
        end
        local ready = pending.phase == 'deploying' and observed.airborne or
            pending.phase ~= 'deploying' and observed.docked
        if not ready then pending.stable = nil; return end
        if not pending.stable then pending.stable = now; return end
        if now-pending.stable < 0.15 then return end
        if pending.phase == 'deploying' then
            self:arm_backpack(keys)
            self:enter(snapshot)
            self.pending = nil
        else
            report('owned drone docking confirmed; deploying for remote control')
            self:backpack_pulse(keys,'deploying')
        end
    end
    function c:enter(snapshot)
        self.stage = 'entry/identity'
        if avoidance then avoidance:clear() end
        assert(not self.pending_cleanup, 'cleanup_pending')
        assert(snapshot.unit_valid() and snapshot.fire_valid() and
            snapshot.camera_valid() and not snapshot.overheated and not snapshot.exhausted, 'entry_not_ready')
        assert(snapshot.kind ~= 'seeker' or snapshot.deployed and not snapshot.detonating, 'seeker_not_deployed')
        assert(reader:word(snapshot.brain.address) == snapshot.behavior_kind, 'drone_behavior_changed')
        assert(snapshot.motion.valid() and snapshot.motion.enabled == '\1', 'drone_motion_not_ready')
        assert(snapshot.movement and snapshot.movement.valid(), 'drone_movement_not_ready')
        assert(reader:raw(snapshot.camera_row,2) == '\4\0', 'camera_not_actor')
        -- Close companion capture and release owned inputs before taking player focus.
        self.stage = 'entry/companion'
        if cooperation then assert(cooperation:acquire(),'companion_input_release_pending') end
        self.stage = 'entry/engine_handles'
        engine:prepare(snapshot)
        if aim and snapshot.kind ~= 'seeker' then
            if snapshot.aim_motor then
                assert(snapshot.aim_motor.valid(), 'aim_motor_not_ready')
                report('aim: native LookAt and firing slot 0 linked; manual turn limit=180deg/s')
            else
                assert(snapshot.aim_motor_reason == 'lookat_component_absent', 'aim_motor_not_ready')
                report('aim: LookAt absent; using verified Targeting/body yaw only; lower-gun pitch not linked')
            end
        end
        local lease = Lease.new(channel)
        self.session = {lease = lease, context = snapshot, token = snapshot.token,
            ownership_key = snapshot.ownership_key, firing = false,
            velocity = {0,0,0}, fire_guard_until = -1,
            input_trace_remaining = 12, input_trace_after = 0}
        self.stage = 'entry/player_input'
        self:arm_inputs(self.keys)
        self.stage = 'entry/leases'
        if snapshot.kind ~= 'seeker' then channel:fire(snapshot,false) end
        self.session.behavior = lease:claim(snapshot.brain.address,B.u32(snapshot.behavior_kind),zero,snapshot.brain.valid)
        -- Behavior and Boids run independently; pause both only on this owned drone.
        self.session.motion = lease:claim(snapshot.motion.address,'\1','\0',snapshot.motion.valid)
        -- Boids pause does not clear the Mover's last direction/speed command.
        self.session.movement = lease:claim(snapshot.movement.address,snapshot.movement.original,
            channel:floats({0,0,0,0}),snapshot.movement.valid)
        if pose then
            self.stage = 'entry/rotation'
            local controls = reader:rotation_controls(snapshot)
            pose:prepare(controls)
            report('rotation: actor turn untouched; body spatial pose linked; body Rotator='..tostring(controls.body ~= nil))
        end
        self:camera_tick(snapshot,snapshot.drone_position)
        local forward = channel:vector(reader:raw(snapshot.camera+0x5C,12),0)
        self.session.yaw = math.atan2(-forward[1],forward[2])
        self.session.pitch = math.asin(math.max(-1,math.min(1,forward[3])))
        self.stage = 'entry/input_capture'
        engine:capture_input()
        channel:mouse_delta()
        self.active, self.status = true,'controlling'
        report(string.format('control keys: forward=%d back=%d left=%d right=%d up=%d down=%d fire=%d',
            self.keys.forward,self.keys.back,self.keys.left,self.keys.right,self.keys.up,self.keys.down,self.keys.fire))
        report('entered '..snapshot.drone_name..' remote control')
    end
    function c:camera_tick(snapshot,position)
        local session = self.session
        assert(snapshot.camera == session.context.camera and snapshot.camera_valid(), 'control_camera_changed')
        local current = session.camera_context
        if current and current.camera_row == snapshot.camera_row and current.camera_valid() and
            reader:raw(snapshot.camera_row,2) == '\0\0' then return end
        -- Actor requests are queued into new rows during play, including weapon input.
        -- Release the old row before claiming another; never retain more than one row.
        if session.camera_lease then
            assert(session.camera_lease:release(),'camera_restore_pending')
        end
        assert(reader:raw(snapshot.camera_row,2) == '\4\0', 'camera_not_actor')
        local lease = Lease.new(channel)
        session.camera_lease,session.camera_context = lease,snapshot
        session.camera_position = lease:claim(snapshot.camera_row+0xB8,
            reader:raw(snapshot.camera_row+0xB8,12),channel:floats(position),snapshot.camera_valid)
        session.camera_rotation = lease:claim(snapshot.camera_row+0xC8,
            reader:raw(snapshot.camera_row+0xC8,16),reader:raw(snapshot.camera_row+0xC8,16),snapshot.camera_valid)
        lease:claim(snapshot.camera_row,'\4\0','\0\0',snapshot.camera_valid)
        if current then report('actor camera request refreshed') end
    end
    function c:hold_seeker_camera(snapshot,reason,duration)
        local session = assert(self.session,'seeker_camera_session_missing')
        assert(self.active and session.context.kind == 'seeker' and snapshot.ticket == self.seeker_ticket and
            session.camera_lease and session.camera_position and session.camera_rotation, 'seeker_camera_hold_not_ready')
        local raw,position = session.camera_position.value,{}
        for axis=1,3 do position[axis] = channel:float(raw,(axis-1)*4) end
        -- Resume native explosion cleanup now; only the camera survives the bomb.
        if pose then pose:clear() end
        assert(session.lease:release(), 'seeker_explosion_release_pending')
        session.behavior,session.motion,session.movement = nil,nil,nil
        engine:seeker_explosion(snapshot)
        self.aftermath = {ticket = snapshot.ticket,reason = reason,until_time = channel:now()+duration,
            position = position,raw_position = raw,rotation = session.camera_rotation.value}
        self.active,self.status = false,'seeker_explosion_view'
        if avoidance then avoidance:clear() end
        report('seeker explosion view: '..reason..'; camera hold='..duration..'s')
    end
    function c:tick(dt)
        if self.pending_cleanup then self:stop('retry_cleanup'); return end
        if not channel:foreground() then
            if self.active or self.pending or self.pulse or self.pack_lease or self.input_lease or self.seeker_ticket or
                self.aftermath or self.seeker and self.seeker.quick_wait then self:stop('focus_lost') end
            if self.seeker then self.seeker:reset() end
            self.hotkey:step(nil); self.keys = nil; return
        end
        if self.pulse and channel:now() >= self.pulse.until_time then
            if not self.pulse.released then
                assert(channel:key(self.pulse.key,false),'backpack_release_failed')
                self.pulse.released,self.pulse.release_deadline = true,channel:now()+0.5
            end
            -- SendInput queues key-up; do not interpret its still-held async state as a fresh cancel.
            if not channel:down(self.pulse.key) then
                self.pulse = nil
                self:reset_inputs()
            else
                assert(channel:now() < self.pulse.release_deadline,'backpack_release_unconfirmed')
            end
        end
        self.stage = 'bindings'
        if not self.pack_lease and not self.input_lease then
            self.keys = reader:bindings()
            local binding = 'aim_mode='..self.keys.aim_mode..'; backpack='..self.keys.backpack..
                '; quick_throw='..tostring(self.keys.quick_throw)
            if binding ~= self.last_binding then self.last_binding = binding; report('bindings: '..binding) end
        end
        local keys = assert(self.keys,'bindings_unavailable')
        assert(keys.valid(), 'bindings_changed')
        if self.aftermath then
            self.stage = 'seeker/explosion_view'
            local view = self.aftermath
            if channel:now() >= view.until_time then self:stop(view.reason); return end
            local snapshot = reader:seeker_camera(view.ticket)
            self:camera_tick(snapshot,view.position)
            self.session.camera_lease:set(self.session.camera_position,view.raw_position)
            self.session.camera_lease:set(self.session.camera_rotation,view.rotation)
            channel:mouse_delta()
            return
        end
        local snapshot
        if self.seeker and not self.pending and (not self.session or self.session.context.kind == 'seeker') then
            local consumed
            consumed,snapshot = self.seeker:monitor(self,keys)
            if consumed then return end
        end
        self.stage = 'snapshot'
        snapshot = snapshot or reader:snapshot()
        if not self.active and not self.pending then self.status = 'ready' end
        local aim_mode_down, backpack_down = channel:down(keys.aim_mode),channel:down(keys.backpack)
        self.stage = 'hotkey'
        if snapshot.kind ~= 'seeker' and not self.active and not self.pending and aim_mode_down then
            self:arm_backpack(keys)
        end
        local event = snapshot.kind ~= 'seeker' and not self.pulse and self.hotkey:step({binding_token = keys.binding_token,backpack_down = backpack_down,
            aim_mode_down = aim_mode_down,control_active = self.active,drone_deployed = snapshot.deployed,
            entry_pending = self.pending ~= nil,
            entry_allowed = not self.pending_cleanup})
        if event == 'exit' then self:stop('backpack_key'); return end
        if not self.active then
            if self.pending then
                self:prepare_tick(snapshot,keys,aim_mode_down,backpack_down)
            elseif event == 'enter' then
                self:begin(snapshot)
            elseif self.pack_lease and not aim_mode_down then
                if not self.pack_lease:release() then self.pending_cleanup = true end
                if #self.pack_lease.items == 0 then self.pack_lease = nil end
            end
            return
        end
        self.stage = 'control/identity'
        if cooperation then assert(cooperation:acquire(),'companion_input_release_pending') end
        local session = self.session
        assert(snapshot.unit_valid() and snapshot.fire_valid(), 'control_owner_changed')
        assert(snapshot.token == session.token, 'control_unit_changed')
        assert(snapshot.node_index == session.context.node_index, 'control_node_changed')
        assert(snapshot.brain.address == session.context.brain.address and snapshot.brain.valid() and
            session.context.brain.valid(), 'control_behavior_changed')
        assert(snapshot.motion.address == session.context.motion.address and snapshot.motion.valid() and
            session.context.motion.valid() and reader:raw(snapshot.motion.address,1) == '\0', 'control_motion_resumed')
        assert(snapshot.movement.address == session.context.movement.address and snapshot.movement.valid() and
            session.context.movement.valid(), 'control_movement_changed')
        self.stage = 'control/camera'
        self:camera_tick(snapshot,snapshot.drone_position)
        if snapshot.overheated then self:stop('overheated_return'); return end
        if snapshot.exhausted then self:stop('ammo_empty_return'); return end
        local observed = engine:observe(snapshot)
        if not observed.free then self:stop('drone_stowed'); return end
        local distance = observed.distance
        if snapshot.kind ~= 'seeker' and distance > 100 then self:stop('signal_lost'); return end
        local behavior = reader:word(snapshot.brain.address)
        if behavior ~= 0 then
            -- Native firing can reset this same drone to its original behavior type.
            -- Reclaim only that known reset during our own fire window, never foreign states.
            assert(behavior == snapshot.behavior_kind and channel:now() <= session.fire_guard_until and
                snapshot.fire_valid() and session.context.fire_valid(), 'control_behavior_resumed')
            session.lease:reassert(session.behavior)
            if not session.fire_reset_reported then
                report('owned drone behavior reset during manual fire; capture renewed')
                session.fire_reset_reported = true
            end
        end
        self.stage = 'control/move'
        local dx,dy = channel:mouse_delta()
        local input = {dx = dx,dy = dy}
        for _, name in ipairs({'forward','back','left','right','up','down'}) do
            input[name] = channel:down(keys[name]) and 1 or 0
        end
        local position,yaw,pitch,camera,quaternion,forward,command,velocity = Flight.step(observed.position,
            session.yaw,session.pitch,input,dt,session.velocity)
        if avoidance then
            self.stage = 'control/clearance'
            local proposed = position
            position,command,velocity = avoidance:move(snapshot,observed.position,velocity,dt,channel:now(),session.velocity)
            for axis = 1,3 do camera[axis] = camera[axis]+position[axis]-proposed[axis] end
        end
        if snapshot.kind ~= 'seeker' and Flight.distance(snapshot.actor_position,position) > 100 then self:stop('signal_lost'); return end
        local signature = string.format('%d%d%d%d%d%d',input.forward,input.back,input.left,input.right,input.up,input.down)
        if session.input_trace_remaining > 0 and signature ~= session.input_trace and
            channel:now() >= session.input_trace_after then
            report(string.format('flight input=%s mouse=%.0f,%.0f speed=%.1fm/s step=%.3fm dt=%.4f',
                signature,dx,dy,command[4],Flight.distance(observed.position,position),dt))
            session.input_trace_remaining = session.input_trace_remaining-1
            session.input_trace,session.input_trace_after = signature,channel:now()+0.25
        end
        session.lease:set(session.movement,channel:floats(command))
        self.stage = 'control/aim'
        local automatic = snapshot.kind ~= 'seeker' and options and options.auto_aim == true or false
        local facing = snapshot.kind ~= 'seeker' and aim and aim:tick(snapshot,camera,forward,automatic,dt)
        local body_rotation = facing and facing.body_rotation or quaternion
        if pose then pose:tick(body_rotation,automatic) end
        engine:move(snapshot,position,body_rotation,forward,automatic)
        session.camera_lease:set(session.camera_position,channel:floats(camera))
        session.camera_lease:set(session.camera_rotation,channel:floats(quaternion))
        session.yaw,session.pitch,session.velocity = yaw,pitch,velocity
        self.stage = 'control/fire'
        local firing = channel:down(keys.fire)
        if snapshot.kind ~= 'seeker' and firing ~= session.firing then
            session.fire_guard_until = channel:now()+1
            channel:fire(snapshot,firing)
            session.firing = firing
            report('manual weapon input: '..(firing and 'pressed' or 'released'))
        end
        if snapshot.kind ~= 'seeker' and firing then session.fire_guard_until = channel:now()+1 end
        self.stage = 'control/hud'
        engine:hud(snapshot,distance,automatic,not avoidance or avoidance.sample ~= nil)
    end
    return c
end
return Controller
