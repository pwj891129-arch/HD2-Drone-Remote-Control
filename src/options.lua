local Options = {}
Options.ID = 'codex.drone_remote_control.auto_aim'
Options.SEEKER_ID = 'codex.drone_remote_control.seeker_homing'
Options.MULTIPLAYER_ID = 'codex.drone_remote_control.allow_multiplayer'
function Options.new(env, channel, B, report, Language, texts)
    local self = {auto_aim = false, seeker_homing = false, allow_multiplayer = false, poll_at = 0}
    local language = Language.new(channel,B,texts)
    local definitions = {
        {id = Options.ID,key = 'auto_aim',label = 'label',description = 'description'},
        {id = Options.SEEKER_ID,key = 'seeker_homing',label = 'seeker_label',description = 'seeker_description'},
        {id = Options.MULTIPLAYER_ID,key = 'allow_multiplayer',label = 'multiplayer_label',description = 'multiplayer_description'},
    }
    local function label(key)
        return function() return language:text(key) end
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
        language:poll(now)
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
