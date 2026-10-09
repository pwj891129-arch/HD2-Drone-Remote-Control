local Pose = {}
function Pose.new(channel, B, Lease)
    local p = {}
    local function hold(lease, item)
        assert(item.valid(), 'rotation_identity_changed')
        local current = channel:read(item.address,#item.value)
        if current ~= item.value then lease:reassert(item) end
    end
    local function pause(lease, controls)
        local items = {}
        if not controls then return items end
        for _, address in ipairs({controls.override,controls.enabled}) do
            local original = assert(channel:read(address,1),'rotation_unreadable')
            assert(original == '\0' or original == '\1', 'rotation_flag_invalid')
            items[#items+1] = lease:claim(address,original,'\0',controls.valid)
        end
        return items
    end
    function p:prepare(controls)
        assert(not self.controls and not self.body_lease and controls.valid(),
            'rotation_not_ready')
        self.controls = controls
    end
    local function same_rotation(a,b)
        local difference, opposite = 0,0
        for i=0,3 do
            local x,y = channel:float(a,i*4),channel:float(b,i*4)
            difference = difference+(x-y)^2
            opposite = opposite+(x+y)^2
        end
        return math.min(difference,opposite) < 1e-10
    end
    function p:refresh()
        local controls = assert(self.controls, 'rotation_not_ready')
        if controls.valid() and (not controls.body or controls.body.valid()) then return end
        local next_controls = assert(controls.resolve and controls.resolve(), 'rotation_owner_changed')
        assert(next_controls.key == controls.key and next_controls.valid() and
            (next_controls.body ~= nil) == (controls.body ~= nil), 'rotation_owner_changed')
        if self.body_lease then
            for i, item in ipairs(self.body_items) do
                local address = i == 1 and next_controls.body.override or next_controls.body.enabled
                self.body_lease:rebind(item,address,next_controls.body.valid)
            end
            local item = self.rotation
            local current = channel:read(next_controls.rotation,16)
            if current and current ~= item.value and same_rotation(current,item.value) then item.value = current end
            self.body_lease:rebind(item,next_controls.rotation,next_controls.valid)
        end
        self.controls = next_controls
    end
    function p:tick(rotation, automatic)
        self:refresh()
        assert(self.controls and self.controls.valid(), 'rotation_owner_changed')
        if automatic then
            self:clear_body()
            return
        end
        local norm = 0
        for i=1,4 do
            local value = rotation[i]
            assert(type(value) == 'number' and value == value and math.abs(value) <= 1,
                'body_rotation_invalid')
            norm = norm+value*value
        end
        assert(math.abs(norm-1) < 0.001, 'body_rotation_invalid')
        local raw = channel:floats(rotation)
        if not self.body_lease then
            self.body_lease = Lease.new(channel)
            self.body_items = pause(self.body_lease,self.controls.body)
            self.rotation = self.body_lease:claim(self.controls.rotation,
                assert(channel:read(self.controls.rotation,16),'body_pose_unreadable'),raw,self.controls.valid)
        else
            for _, item in ipairs(self.body_items) do hold(self.body_lease,item) end
            local item = self.rotation
            assert(item.valid(), 'body_pose_changed')
            local current = assert(channel:read(item.address,16),'body_pose_unreadable')
            if current ~= item.value and same_rotation(current,item.value) then
                -- Engine quaternion normalization/sign changes preserve our rotation.
                item.value = current
            elseif current ~= item.value then
                self.body_lease:reassert(item)
            end
            self.body_lease:set(item,raw)
        end
    end
    function p:clear_body()
        if not self.body_lease then return end
        -- Never restore stale buffers; refresh only copied bytes on the exact same drone.
        pcall(self.refresh,self)
        assert(self.body_lease:release(), 'body_rotation_restore_pending')
        self.body_lease,self.body_items,self.rotation = nil,nil,nil
    end
    function p:clear()
        self:clear_body()
        self.controls = nil
    end
    return p
end
return Pose
