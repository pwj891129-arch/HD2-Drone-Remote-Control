local Options = {}
Options.ID = 'codex.drone_remote_control.auto_aim'
function Options.new(env, channel, B, report)
    local self = {auto_aim = false, poll_at = 0}
    local ko = {
        mod = '\235\147\156\235\161\160 \236\155\144\234\178\169\236\161\176\236\162\133',
        label = '\236\158\144\235\143\153\236\161\176\236\164\128',
        description = '\236\188\156\234\184\176: \236\160\129 \237\145\156\236\160\129 \236\182\148\236\160\129. \235\129\132\234\184\176: \236\185\180\235\169\148\235\157\188 \235\176\169\237\150\165\236\156\188\235\161\156 \236\136\152\235\143\153 \236\161\176\236\164\128. \234\184\176\235\179\184\234\176\146\236\157\128 \235\129\132\234\184\176.',
    }
    local en = {mod = 'Drone Remote Control', label = 'Auto Aim',
        description = 'On: track enemy targets. Off: aim manually with the camera. Default: Off.'}
    local function language()
        -- Same game Text Language records used by HD2 Helper, with English fallback.
        local ok, code = pcall(function()
            local root = B.ptr(assert(channel:read(channel.base+0x3326340,8)))
            local index = B.word(assert(channel:read(root+705712,4)),0)
            assert(index < 15)
            local record = B.ptr(assert(channel:read(channel.base+0x37C5650+index*8,8)))
            local at = B.ptr(assert(channel:read(record+8,8)))
            return assert(channel:read(at,8)):match('^(%a[%w%-_]*)%z')
        end)
        code = ok and type(code) == 'string' and code:lower():gsub('_','-') or ''
        return (code == 'kr' or code == 'ko' or code == 'ko-kr') and 'ko' or 'en'
    end
    local function label(key)
        return function() return (language() == 'ko' and ko or en)[key] end
    end
    local function change(value)
        if type(value) ~= 'boolean' or self.auto_aim == value then return end
        self.auto_aim = value
        report('auto aim: '..(value and 'ON' or 'OFF'))
    end
    function self:tick(now)
        if type(now) ~= 'number' or now ~= now or now < 0 or now == math.huge then return end
        if self.previous and now < self.previous then self.poll_at,self.retry_at = 0,0 end
        self.previous = now
        if now < self.poll_at then return end
        self.poll_at = now+0.25
        local menu = rawget(env,'ModOptionsMenu')
        if type(menu) ~= 'table' or menu.api ~= 1 or type(menu.version) ~= 'number' or menu.version < 3 or
            type(menu.register_option) ~= 'function' or type(menu.get) ~= 'function' or
            type(menu.on_change) ~= 'function' then return end
        if self.menu ~= menu then
            self.menu,self.registered,self.subscribed,self.retry_at = menu,false,false,0
        end
        if not self.registered and now >= self.retry_at then
            local ok, registered = pcall(menu.register_option,Options.ID,
                {type = 'toggle',mod_id = 'codex.drone_remote_control',mod = label('mod'),
                    label = label('label'),description = label('description'),default = false})
            self.registered = ok and registered == true
            if not self.registered then self.retry_at = now+2; return end
            report('in-game Auto Aim option registered; default OFF')
        end
        if not self.registered then return end
        if not self.subscribed then
            local ok, subscribed = pcall(menu.on_change,Options.ID,function(value)
                if rawget(env,'ModOptionsMenu') == menu then change(value) end
            end)
            self.subscribed = ok and subscribed ~= false
        end
        local ok, value = pcall(menu.get,Options.ID)
        if ok then change(value) end
    end
    return self
end
return Options
