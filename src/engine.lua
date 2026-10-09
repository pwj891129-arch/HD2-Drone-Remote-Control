local Engine = {}
function Engine.new(s, Flight, report, channel)
    local adapter = {screen = nil, texts = {}}
    local V, U, W = s.Vector3, s.Unit, s.World
    local function vector(v)
        local x,y,z
        if type(V.to_elements) == 'function' then x,y,z = V.to_elements(v)
        else x,y,z = V.x(v),V.y(v),V.z(v) end
        local result = {x,y,z}
        for i=1,3 do
            local value = result[i]
            if type(value) == 'cdata' then value = tonumber(value) end
            assert(type(value) == 'number' and value == value and math.abs(value) < 1000000,
                'unit_position_invalid: component='..i..' type='..type(result[i])..' value='..tostring(result[i]))
            result[i] = value
        end
        return result
    end
    local function world_position(unit) return vector(U.world_position(unit,adapter.node)) end
    local function note(message) if report then report('engine: '..message) end end
    local function resolve(resource, goid, reference)
        assert(type(resource) == 'string' and #resource == 16 and not resource:find('[^0-9a-f]') and
            resource ~= '0000000000000000', 'unit_native_resource_unavailable')
        local world = s.Application.main_world()
        assert(world, 'world_unavailable')
        assert(channel and type(channel.unit_ref) == 'function' and type(reference) == 'number' and
            reference > 0 and reference < 1073741824 and reference % 1 == 0, 'unit_reference_unavailable')
        local match
        local sync_api, session_api, network = s.UnitSynchronizer,s.GameSession,s.Network
        if sync_api and session_api and network and
            type(sync_api.game_object_id_to_unit) == 'function' and
            type(session_api.unit_synchronizer) == 'function' and type(network.game_session) == 'function' then
            local session = network.game_session()
            local sync = session and session ~= 0 and session_api.unit_synchronizer(session)
            if sync and sync ~= 0 then
                assert(type(goid) == 'number' and goid > 0 and goid < 32767 and goid % 1 == 0,
                    'unit_goid_invalid')
                match = sync_api.game_object_id_to_unit(sync,goid)
                if match and match ~= 0 then
                    assert(channel:unit_ref(match) == reference and U.alive(match),
                        'unit_goid_mismatch:'..resource)
                    world_position(match)
                    if type(sync_api.unit_to_game_object_id) == 'function' then
                        assert(sync_api.unit_to_game_object_id(sync,match) == goid, 'unit_goid_changed')
                    end
                    note('resolved resource='..resource..' path=game_object_id')
                else match = nil end
            end
        end
        if not match then
            -- IdString64 is opaque; tostring(resource_name) is not its resource hash.
            local ids = s.IdString64
            assert(ids and type(ids.from_hex) == 'function' and type(W.units_by_resource) == 'function',
                'unit_resource_lookup_unavailable')
            local units = W.units_by_resource(world,ids.from_hex(resource))
            assert(type(units) == 'table', 'units_unavailable:'..resource)
            local count, seen, references = 0,{},{}
            for _, unit in pairs(units) do
                count = count+1; assert(count <= 512, 'unit_resource_budget')
                local candidate = channel:unit_ref(unit)
                if #references < 12 then references[#references+1] = tostring(candidate)..'('..type(unit)..')' end
                if not seen[unit] and candidate == reference then
                    seen[unit] = true
                    assert(U.alive(unit), 'unit_not_alive:'..resource)
                    world_position(unit)
                    assert(not match, 'unit_handle_ambiguous:'..resource); match = unit
                end
            end
            note('lookup resource='..resource..' candidates='..count..' unit_ref='..reference..
                ' node='..adapter.node..' matched='..tostring(match~=nil)..' refs='..table.concat(references,','))
        end
        assert(match, 'unit_handle_unavailable:'..resource)
        if type(U.world) == 'function' then assert(U.world(match) == world, 'unit_world_mismatch') end
        return match, world
    end
    function adapter:observe(snapshot)
        assert(snapshot.node_index == 0 or snapshot.node_index == 1, 'node_index_unavailable')
        assert(snapshot.unit_valid(), 'unit_identity_changed')
        if self.token ~= snapshot.token or self.node ~= snapshot.node_index then
            self.node = snapshot.node_index
            self.drone,self.world = resolve(snapshot.drone_engine_resource,snapshot.drone_goid,snapshot.drone_unit)
            self.gun = snapshot.kind == 'seeker' and self.drone or
                resolve(snapshot.gun_engine_resource,snapshot.gun_goid,snapshot.gun_unit)
            self.token = snapshot.token
        end
        assert(U.alive(self.drone) and U.alive(self.gun) and self.world == s.Application.main_world() and
            channel:unit_ref(self.drone) == snapshot.drone_unit and
            channel:unit_ref(self.gun) == snapshot.gun_unit and snapshot.unit_valid(), 'unit_handle_changed')
        local position = world_position(self.drone)
        vector(U.local_position(self.drone,self.node))
        assert(snapshot.graph_valid() and (snapshot.kind == 'seeker' or
            type(snapshot.pack_unit) == 'number' and type(snapshot.actor_unit) == 'number' and
            snapshot.pack_parent_unit == snapshot.actor_unit and snapshot.gun_parent_unit == snapshot.drone_unit),
            'unit_parent_graph_changed')
        local parented = snapshot.drone_parent_unit ~= nil
        local distance = Flight.distance(position,snapshot.actor_position)
        return {docked = snapshot.kind ~= 'seeker' and snapshot.drone_parent_unit == snapshot.pack_unit,
            airborne = not parented and (snapshot.kind == 'seeker' or distance > 1.5), free = not parented,
            parent_ref = snapshot.drone_parent_unit, position = position, distance = distance}
    end
    function adapter:prepare(snapshot)
        assert(type(s.Quaternion) == 'table' and type(s.Quaternion.from_elements) == 'function',
            'quaternion_elements_api_unavailable')
        assert(type(U.teleport_local_rotation) == 'function', 'rotation_update_api_unavailable')
        assert(self:observe(snapshot).airborne, 'drone_not_airborne')
        assert(snapshot.movement and snapshot.movement.valid(), 'drone_movement_not_ready')
        self.node = snapshot.node_index
        note('root node='..self.node)
        assert(type(s.Window.mouse_focus) == 'function' and type(s.Window.set_mouse_focus) == 'function' and
            type(s.Window.show_cursor) == 'function' and type(s.Window.set_show_cursor) == 'function',
            'mouse_focus_api_unavailable')
        self.trace_move,self.trace_hud = true,true
        for _,name in ipairs({'PhysicsWorld','Physics'}) do
            local surface,methods = rawget(s,name),{}
            if type(surface) == 'table' then
                for key,value in next,surface do
                    if type(key) == 'string' and type(value) == 'function' and #methods < 64 then
                        methods[#methods+1] = key:gsub('[^%w_]','?'):sub(1,64)
                    end
                end
                table.sort(methods)
            end
            note('collision API '..name..'='..(type(surface) == 'table' and table.concat(methods,',') or 'unavailable'))
        end
    end
    function adapter:move(snapshot, position, quaternion, target, automatic)
        assert(type(position) == 'table' and type(quaternion) == 'table', 'flight_transform_invalid')
        for i=1,3 do
            local value = position[i]
            assert(type(value) == 'number' and value == value and math.abs(value) < 1000000,
                'flight_position_invalid')
        end
        local norm = 0
        for i=1,4 do
            local value = quaternion[i]
            assert(type(value) == 'number' and value == value and math.abs(value) <= 1,
                'flight_rotation_invalid')
            norm = norm+value*value
        end
        assert(math.abs(norm-1) < 0.001, 'flight_rotation_not_unit')
        assert(snapshot.node_index == self.node and U.alive(self.drone) and U.alive(self.gun) and
            self.world == s.Application.main_world() and
            channel:unit_ref(self.drone) == snapshot.drone_unit and
            channel:unit_ref(self.gun) == snapshot.gun_unit and snapshot.unit_valid(),
            'unit_handle_changed')
        assert(self:observe(snapshot).free, 'drone_parented')
        assert(snapshot.movement and snapshot.movement.valid(), 'drone_movement_changed')
        if self.trace_move then note('first move: Quaternion.from_elements') end
        -- Quaternion(...) is axis-angle; numeric components require from_elements.
        local rotation = s.Quaternion.from_elements(quaternion[1],quaternion[2],quaternion[3],quaternion[4])
        -- Mover consumes direction/speed; separate probes provide surface clearance.
        -- Body follows yaw; native LookAt owns the lower weapon's pitch nodes.
        -- Keep translation in Mover and do not pitch the body as if it were the gun.
        if self.trace_move then note('first move: owned Mover input; no scene-root teleport') end
        if self.trace_move then note('first move: Unit.teleport_local_rotation') end
        if not automatic then U.teleport_local_rotation(self.drone,self.node,rotation) end
        if self.trace_move then note('first move: World.update_unit body') end
        W.update_unit(self.world,self.drone)
        if self.trace_move then note('first move: World.update_unit laser') end
        if self.gun ~= self.drone then W.update_unit(self.world,self.gun) end
        if self.trace_move then note('first move: complete'); self.trace_move = false end
    end
    function adapter:capture_input()
        local mouse, cursor = s.Window.mouse_focus(),s.Window.show_cursor()
        assert(type(mouse) == 'boolean' and type(cursor) == 'boolean', 'mouse_focus_state_unavailable')
        self.focus = {mouse = mouse,cursor = cursor}
        s.Window.set_mouse_focus(false); s.Window.set_show_cursor(false)
    end
    function adapter:restore_input()
        if not self.focus then return true end
        if not channel:foreground() then return false end
        if s.Window.mouse_focus() == false then s.Window.set_mouse_focus(self.focus.mouse) end
        if s.Window.show_cursor() == false then s.Window.set_show_cursor(self.focus.cursor) end
        self.focus = nil
        return true
    end
    function adapter:hud(snapshot, distance, automatic, surface_ready)
        local gui_api, color = s.Gui, s.Color
        assert(gui_api and color and s.Vector2 and s.Application.can_get('font','core/performance_hud/debug') and
            s.Application.can_get('material','core/performance_hud/debug'), 'hud_api_unavailable')
        local worlds = s.Application.worlds()
        local live = false
        for _, world in pairs(worlds) do if world == self.gui_world then live = true end end
        if not live then self.screen, self.texts = nil,{} end
        if not self.screen then
            for _, world in pairs(worlds) do
                if world ~= self.world then self.gui_world = world; break end
            end
            assert(self.gui_world, 'hud_ui_world_unavailable')
            if self.trace_hud then note('first HUD: World.create_screen_gui') end
            self.screen = W.create_screen_gui(self.gui_world,'scale',1,1)
            assert(self.screen and self.screen ~= 0, 'hud_create_failed')
        end
        for _, id in ipairs(self.texts) do gui_api.destroy_text(self.screen,id) end
        self.texts = {}
        local width, height = gui_api.resolution()
        assert(type(width) == 'number' and type(height) == 'number' and width >= 480 and height >= 320,
            'hud_resolution')
        local weapon = snapshot.kind == 'seeker' and string.format('TIME %.1fs',snapshot.remaining or 0) or
            snapshot.feed == 'magazine' and
            string.format('AMMO %d   MAGAZINES %d',snapshot.ammo,snapshot.reserve) or
            string.format('HEAT %.2f   HEATSINKS %d',snapshot.heat,snapshot.reserve)
        local label = snapshot.kind == 'seeker' and string.format('%s  %.1fm   %s',snapshot.drone_name,distance,weapon) or
            string.format('%s  %.1fm / 100m   %s   AIM %s',
                snapshot.drone_name or 'ROVER',distance,weapon,automatic and 'AUTO' or 'MANUAL')
        if surface_ready == false then label = label..'   SURFACE WAIT' end
        local tint = snapshot.kind == 'seeker' and {255,240,240,220} or Flight.color(distance)
        local font = 'core/performance_hud/debug'
        if self.trace_hud then note('first HUD: Gui.text_extents') end
        local minimum, maximum = gui_api.text_extents(self.screen,label,font,24)
        local x = (width - (maximum.x-minimum.x))/2
        if self.trace_hud then note('first HUD: Gui.text') end
        local y = height*0.70
        self.texts[#self.texts+1] = assert(gui_api.text(self.screen,label,font,24,font,V(x+1,y-1,12),
            color(240,0,0,0)), 'hud_text_failed')
        self.texts[#self.texts+1] = assert(gui_api.text(self.screen,label,font,24,font,V(x,y,13),
            color(tint[1],tint[2],tint[3],tint[4])), 'hud_text_failed')
        if self.trace_hud then note('first HUD: complete'); self.trace_hud = false end
    end
    function adapter:clear()
        assert(self:restore_input(), 'mouse_restore_pending')
        if self.screen then
            local worlds = s.Application.worlds()
            for _, world in pairs(worlds) do
                if world == self.gui_world then W.destroy_gui(world,self.screen); break end
            end
            self.screen, self.texts = nil, {}
        end
        self.drone,self.gun,self.world,self.gui_world,self.node,self.token = nil,nil,nil,nil,nil,nil
        self.trace_move,self.trace_hud = nil,nil
    end
    return adapter
end
return Engine
