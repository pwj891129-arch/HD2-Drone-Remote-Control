local B = {}
function B.word(s, at)
    assert(type(s) == 'string' and #s >= at + 4, 'short_read')
    local a, b, c, d = s:byte(at + 1, at + 4)
    return a + b * 256 + c * 65536 + d * 16777216
end
function B.ptr(s)
    local p = B.word(s, 0) + B.word(s, 4) * 4294967296
    assert(p >= 65536 and p < 140737488355328, 'invalid_pointer')
    return p
end
function B.u32(n)
    return string.char(n % 256, math.floor(n / 256) % 256,
        math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end
function B.hex(s) return (s:gsub('.', function(c) return string.format('%02x', c:byte()) end)) end
function B.unhex(s) return (s:gsub('..', function(c) return string.char(tonumber(c, 16)) end)) end
function B.mul(a, b)
    return (a % 65536 * (b % 65536) + ((math.floor(a / 65536) * (b % 65536) +
        a % 65536 * math.floor(b / 65536)) % 65536) * 65536) % 4294967296
end
return B
