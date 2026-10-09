local Options = {}
Options.ID = 'codex.drone_remote_control.auto_aim'
Options.SEEKER_ID = 'codex.drone_remote_control.seeker_homing'
Options.MULTIPLAYER_ID = 'codex.drone_remote_control.allow_multiplayer'
function Options.new(env, channel, B, report)
    local self = {auto_aim = false, seeker_homing = false, allow_multiplayer = false, poll_at = 0}
    local ko = {
        mod = '\235\147\156\235\161\160 \236\155\144\234\178\169\236\161\176\236\162\133',
        label = '\236\158\144\235\143\153\236\161\176\236\164\128',
        description = '\236\188\156\234\184\176: \236\160\129 \237\145\156\236\160\129 \236\182\148\236\160\129. \235\129\132\234\184\176: \236\185\180\235\169\148\235\157\188 \235\176\169\237\150\165\236\156\188\235\161\156 \236\136\152\235\143\153 \236\161\176\236\164\128. \234\184\176\235\179\184\234\176\146\236\157\128 \235\129\132\234\184\176.',
    }
    local en = {mod = 'Drone Remote Control', label = 'Auto Aim',
        description = 'On: track enemy targets. Off: aim manually with the camera. Default: Off.'}
    ko.seeker_label = '\236\139\156\236\187\164 \236\156\160\235\143\132 \235\179\180\236\161\176'
    ko.seeker_description = '\236\188\156\234\184\176: \236\160\129\236\157\132 \234\176\144\236\167\128\237\149\180 \236\156\160\235\143\132\237\149\169\235\139\136\235\139\164. \236\157\180\235\143\153\237\130\164\236\153\128 \235\167\136\236\154\176\236\138\164 \236\161\176\236\158\145\236\157\180 \236\154\176\236\132\160\237\149\169\235\139\136\235\139\164. \235\129\132\234\184\176: \236\136\152\235\143\153 \235\185\132\237\150\137\235\167\140 \236\130\172\236\154\169\237\149\169\235\139\136\235\139\164. \234\184\176\235\179\184\234\176\146\236\157\128 \235\129\132\234\184\176.'
    en.seeker_label = 'Seeker Homing Assist'
    en.seeker_description = 'On: detect and home toward enemies. Movement keys and mouse input take priority. Off: manual flight only. Default: Off.'
    ko.multiplayer_label = '\235\169\128\237\139\176\237\148\140\235\160\136\236\157\180 \237\151\136\236\154\169'
    ko.multiplayer_description = '\236\188\156\234\184\176: \237\140\140\237\139\176\236\151\144\236\132\156\235\143\132 \235\179\184\236\157\184 \235\147\156\235\161\160 \236\161\176\236\162\133 \237\151\136\236\154\169. \235\129\132\234\184\176: \237\152\188\236\158\144\236\157\188 \235\149\140\235\167\140 \236\161\176\236\162\133. \234\184\176\235\179\184\234\176\146\236\157\128 \235\129\132\234\184\176. \235\169\128\237\139\176 \235\143\153\236\158\145\236\157\128 \236\139\156\237\151\152 \236\164\145\236\158\133\235\139\136\235\139\164.'
    en.multiplayer_label = 'Allow Multiplayer'
    en.multiplayer_description = 'On: allow control of your own drones in a party. Off: solo only. Default: Off. Multiplayer behavior is experimental.'
    local definitions = {
        {id = Options.ID,key = 'auto_aim',label = 'label',description = 'description'},
        {id = Options.SEEKER_ID,key = 'seeker_homing',label = 'seeker_label',description = 'seeker_description'},
        {id = Options.MULTIPLAYER_ID,key = 'allow_multiplayer',label = 'multiplayer_label',description = 'multiplayer_description'},
    }
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
    local function change(key,value)
        if type(value) ~= 'boolean' or self[key] == value then return end
        self[key] = value
        report(key..': '..(value and 'ON' or 'OFF'))
    end
    function self:tick(now)
        if type(now) ~= 'number' or now ~= now or now < 0 or now == math.huge then return end
        if self.previous and now < self.previous then
            self.poll_at = 0
            for _,item in ipairs(definitions) do item.retry_at = 0 end
        end
        self.previous = now
        if now < self.poll_at then return end
        self.poll_at = now+0.25
        local menu = rawget(env,'ModOptionsMenu')
        if type(menu) ~= 'table' or menu.api ~= 1 or type(menu.version) ~= 'number' or menu.version < 3 or
            type(menu.register_option) ~= 'function' or type(menu.get) ~= 'function' or
            type(menu.on_change) ~= 'function' then return end
        if self.menu ~= menu then
            self.menu = menu
            for _,item in ipairs(definitions) do item.registered,item.subscribed,item.retry_at = false,false,0 end
        end
        for _,item in ipairs(definitions) do
            if not item.registered and now >= item.retry_at then
                local ok, registered = pcall(menu.register_option,item.id,
                    {type = 'toggle',mod_id = 'codex.drone_remote_control',mod = label('mod'),
                        label = label(item.label),description = label(item.description),default = false})
                item.registered = ok and registered == true
                if not item.registered then item.retry_at = now+2
                else report('in-game '..item.key..' option registered; default OFF') end
            end
            if item.registered then
                if not item.subscribed then
                    local ok, subscribed = pcall(menu.on_change,item.id,function(value)
                        if rawget(env,'ModOptionsMenu') == menu then change(item.key,value) end
                    end)
                    item.subscribed = ok and subscribed ~= false
                end
                local ok, value = pcall(menu.get,item.id)
                if ok then change(item.key,value) end
            end
        end
    end
    return self
end
return Options
