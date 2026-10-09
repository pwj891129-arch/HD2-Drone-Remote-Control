local Parts = {}
local bit = require('bit')
Parts.game_guards = {
    {0x507435,'488b055c4bf602'},
    {0x50743F,'4c8b90782bf100'},
    {0x507470,'418bc048c1e0044903c2488b10'},
}
-- Actor.unit/name use the same generation-checked registry lookup.
Parts.engine_guards = {
    {0x7951B0,'448bc18bc148c1e81e49c1e81c448bc94183e003'},
    {0x7951C4,'488d0d3549bd01'},
    {0x7951DA,'418bc9234828394824763044854834742a'},
    {0x7951EB,'8b501c4c8b108bc2c1e810440fb7c2440fafc10fb6c84103c846390c11'},
    {0x79520A,'c1ea18418d04104903c2c3'},
    {0x79998E,'8b400c'},
    {0x799CF3,'8b4018'},
}
function Parts.new(reader,B)
    local channel,verified = reader.channel,false
    local p = {definitions = {},definition_count = 0}
    function p:verify()
        for _,pair in ipairs({{Parts.game_guards,channel.base},{Parts.engine_guards,channel.exe_base}}) do
            for _,guard in ipairs(pair[1]) do
                local raw = B.unhex(guard[2])
                assert(reader:raw(pair[2]+guard[1],#raw) == raw,'body_part_code_changed')
            end
        end
        verified = true
    end
    function p:definition(meta)
        local resource = meta.identity:sub(1,8)
        local table_at = reader:ptr(meta.authored+0xF12B78)
        if self.authored ~= meta.authored or self.table_at ~= table_at then
            self.authored,self.table_at = meta.authored,table_at
            self.definitions,self.definition_count = {},0
        end
        local cached = self.definitions[resource]
        if cached and reader:raw(cached.slot,16) == cached.identity then
            assert(reader:ptr(meta.authored+0xF12B78) == table_at,'body_part_definition_changed')
            return cached.names
        end
        local index = 0
        -- Byte-wise modulo avoids losing bits of the 64-bit resource name.
        for i = 8,1,-1 do index = (index*256+resource:byte(i))%1002 end
        for _ = 1,1002 do
            local slot = table_at+index*16
            local raw = reader:raw(slot,16)
            if raw:sub(1,8) == resource then
                local dense = B.word(raw,8)
                assert(dense < 1002,'body_part_definition_bounds')
                local record = table_at+0x3EA0+dense*0x5650
                local bytes = reader:raw(record,0x5650)
                local names = {}
                for zone = 0,37 do
                    local at = 0x208+zone*0x228
                    if B.word(bytes,at+96) == 0 then break end
                    for part = 0,23 do
                        local name = B.word(bytes,at+456+part*4)
                        if name == 0 then break end
                        names[name] = true
                    end
                end
                assert(reader:ptr(meta.authored+0xF12B78) == table_at and
                    reader:raw(slot,16) == raw,'body_part_definition_changed')
                if self.definition_count >= 64 then
                    self.definitions,self.definition_count = {},0
                end
                if not self.definitions[resource] then self.definition_count = self.definition_count+1 end
                self.definitions[resource] = {slot = slot,identity = raw,names = names}
                return names
            end
            if raw:sub(1,8) == string.rep('\0',8) then return {} end
            index = (index+1)%1002
        end
        return {}
    end
    function p:matches(meta,unit,actor)
        assert(meta and meta.valid(),'body_part_owner_changed')
        assert(type(actor) == 'number' and actor >= 0 and actor < 4294967296 and actor%1 == 0,
            'body_part_reference_invalid')
        if not verified then self:verify() end
        local kind,world = math.floor(actor/1073741824),math.floor(actor/268435456)%4
        local manager = channel.exe_base+0x2369B00+(kind*10+world)*64
        local header = reader:raw(manager,64)
        local packed,count,mask,live_mask = B.word(header,28),B.word(header,36),B.word(header,40),B.word(header,52)
        local stride,reference_at,data_at = packed%65536,math.floor(packed/65536)%256,math.floor(packed/16777216)
        assert(mask >= 1 and mask <= 131071 and mask+1 == count,'body_part_registry_mask')
        local index = actor%(mask+1)
        if not (count <= 131072 and index < count and stride >= 32 and stride <= 256 and
            reference_at+4 <= stride and data_at+28 <= stride and live_mask ~= 0) then
            error(string.format('body_part_registry_bounds: actor=%08x count=%d stride=%d ref=%d data=%d live=%08x',
                actor,count,stride,reference_at,data_at,live_mask),0)
        end
        local function registry_valid()
            return reader:raw(manager,64) == header and meta.valid()
        end
        -- The native Actor lookup returns null for inactive/recycled handles.
        -- They are not live damage parts and must not freeze an entire scan.
        if bit.band(actor,live_mask) == 0 then
            assert(registry_valid(),'body_part_actor_changed')
            return false
        end
        local address = B.ptr(header)+index*stride
        local bytes = reader:raw(address,stride)
        if B.word(bytes,reference_at) ~= actor then
            assert(registry_valid() and reader:raw(address,stride) == bytes,'body_part_actor_changed')
            return false
        end
        assert(B.word(bytes,data_at+12) == unit,'body_part_actor_changed')
        local name = B.word(bytes,data_at+24)
        meta.parts = self:definition(meta)
        assert(registry_valid() and reader:raw(address,stride) == bytes,'body_part_actor_changed')
        return meta.parts[name] == true,name
    end
    return p
end
return Parts
