local Lease = {}
function Lease.new(channel)
    local lease = {items = {}, conflicts = 0}
    function lease:claim(address, expected, replacement, valid)
        assert(valid() and channel:read(address, #expected) == expected, 'lease_changed')
        local item = {address = address, original = expected, value = replacement, valid = valid}
        -- Record before writing: even a failed readback must still be rolled back.
        self.items[#self.items + 1] = item
        assert(channel:write(address, replacement), 'lease_write_failed')
        assert(channel:read(address, #replacement) == replacement, 'lease_readback_failed')
        return item
    end
    function lease:set(item, replacement)
        assert(item.valid() and channel:read(item.address, #item.value) == item.value, 'lease_lost')
        if replacement == item.value then return end
        item.pending = replacement
        assert(channel:write(item.address, replacement), 'lease_write_failed')
        item.value, item.pending = replacement, nil
        assert(channel:read(item.address, #replacement) == replacement, 'lease_readback_failed')
    end
    function lease:reassert(item)
        local found = false
        for _, owned in ipairs(self.items) do if owned == item then found = true; break end end
        assert(found and item.valid() and channel:read(item.address,#item.original) == item.original,
            'lease_reset_changed')
        item.pending = item.value
        assert(channel:write(item.address,item.value), 'lease_write_failed')
        item.pending = nil
        assert(channel:read(item.address,#item.value) == item.value, 'lease_readback_failed')
    end
    function lease:adopt_unchanged(item, expected)
        local found = false
        for _, owned in ipairs(self.items) do if owned == item then found = true; break end end
        -- Only an unchanged producer value can yield to a caller-verified native reset.
        -- Modified configuration leases must keep their original restoration value.
        assert(found and item.original == item.value and #expected == #item.value and
            item.valid() and channel:read(item.address,#expected) == expected,'lease_adopt_changed')
        item.original,item.value = expected,expected
    end
    function lease:rebind(item, address, valid)
        -- The caller must resolve the same owner/generation before refreshing storage.
        local found = false
        for _, owned in ipairs(self.items) do if owned == item then found = true; break end end
        assert(found and valid(), 'lease_rebind_identity')
        local old_ok, old_valid = pcall(item.valid)
        assert(address == item.address or not (old_ok and old_valid), 'lease_rebind_live_source')
        local current = channel:read(address,#item.value)
        assert(current and (current == item.value or current == item.pending or current == item.original),
            'lease_rebind_changed')
        assert(valid(), 'lease_rebind_identity')
        item.address,item.valid = address,valid
    end
    function lease:release()
        local remaining = {}
        for index = #self.items, 1, -1 do
            local item = self.items[index]
            local ok, owned = pcall(function()
                local current = channel:read(item.address, #item.value)
                return current and item.valid() and (current == item.value or current == item.pending)
            end)
            if ok and owned then
                local restored, result = pcall(function()
                    return channel:write(item.address, item.original) and
                        channel:read(item.address, #item.original) == item.original
                end)
                if not restored or not result then remaining[#remaining + 1] = item end
            else
                self.conflicts = self.conflicts + 1
            end
        end
        self.items = remaining
        return #remaining == 0
    end
    return lease
end
return Lease
