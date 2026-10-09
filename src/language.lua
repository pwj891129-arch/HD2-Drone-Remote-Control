local Language = {}
Language.interval = 0.25
Language.codes = {
    us = 'en',en = 'en',['en-us'] = 'en',uk = 'en',gb = 'en',['en-gb'] = 'en',
    fr = 'fr',it = 'it',de = 'de',es = 'es',['es-es'] = 'es',
    mx = 'es-419',['es-mx'] = 'es-419',['es-419'] = 'es-419',
    jp = 'ja',ja = 'ja',['ja-jp'] = 'ja',kr = 'ko',ko = 'ko',['ko-kr'] = 'ko',
    br = 'pt-BR',['pt-br'] = 'pt-BR',pt = 'pt',['pt-pt'] = 'pt',pl = 'pl',ru = 'ru',
    cn = 'zh-Hans',zh = 'zh-Hans',zhs = 'zh-Hans',['zh-cn'] = 'zh-Hans',['zh-hans'] = 'zh-Hans',
    tw = 'zh-Hant',zht = 'zh-Hant',['zh-tw'] = 'zh-Hant',['zh-hant'] = 'zh-Hant',
}
function Language.resolve(code)
    if type(code) ~= 'string' then return 'en' end
    return Language.codes[code:lower():gsub('_','-')] or 'en'
end
function Language.new(channel, B, texts)
    local self = {current = 'en',poll_at = 0}
    local function read(at,size)
        local bytes = channel:read(at,size)
        if type(bytes) == 'string' and #bytes == size then return bytes end
    end
    local function selected()
        -- Read the game's Text Language record, never a fixed language-index ordering.
        local root = B.ptr(assert(read(channel.base+0x3326340,8)))
        local index = B.word(assert(read(root+705712,4)),0)
        assert(index < 15,'language_index_out_of_range')
        local record = B.ptr(assert(read(channel.base+0x37C5650+index*8,8)))
        local at = B.ptr(assert(read(record+8,8)))
        local ok,bytes = pcall(read,at,16)
        if not ok or not bytes then bytes = read(at,8) end
        local code = assert(bytes):match('^(%a[%w%-_]*)%z')
        assert(code and #code <= 12,'invalid_language_code')
        return Language.resolve(code)
    end
    function self:poll(now)
        if type(now) ~= 'number' or now ~= now or now < 0 or now == math.huge then return end
        if self.previous and now < self.previous then self.poll_at = 0 end
        self.previous = now
        if now < self.poll_at then return end
        self.poll_at = now+Language.interval
        local ok,locale = pcall(selected)
        self.current = ok and texts[locale] and locale or 'en'
    end
    function self:text(key)
        return (texts[self.current] or {})[key] or texts.en[key]
    end
    return self
end
return Language
