local Options,B = ...
local checks=0
local function check(value,message) assert(value,message);checks=checks+1 end
local function fixture()
    local env,channel,logs={},{base=0x10000000,code='EN'},{}
    local function ptr(value) return B.u32(value)..B.u32(0) end
    function channel:read(at,size)
        if self.fail then return nil end
        if at==self.base+0x3326340 then return ptr(0x70000000) end
        if at==0x70000000+705712 then return B.u32(self.index or 0) end
        if at==self.base+0x37C5650 then return ptr(0x71000000) end
        if at==0x71000000+8 then return ptr(0x72000000) end
        if at==0x72000000 then return self.code..string.rep('\0',size-#self.code) end
    end
    local options=Options.new(env,channel,B,function(message)logs[#logs+1]=message end)
    local function provider(aim,homing,multiplayer)
        local menu={api=1,version=3,registers=0,reads=0,specs={},callbacks={},
            values={[Options.ID]=aim,[Options.SEEKER_ID]=homing,[Options.MULTIPLAYER_ID]=multiplayer == true}}
        function menu.register_option(id,spec)
            check(id==Options.ID or id==Options.SEEKER_ID or id==Options.MULTIPLAYER_ID,'stable persisted option ids')
            menu.registers=menu.registers+1
            if menu.reject==true or menu.reject==id then return false end
            menu.specs[id]=spec;return true
        end
        function menu.get(id)
            menu.reads=menu.reads+1
            if menu.fail==true or menu.fail==id then error('temporary provider failure') end
            return menu.values[id]
        end
        function menu.on_change(id,callback)
            if menu.reject_subscription then return false end
            menu.callbacks[id]=callback;return true
        end
        env.ModOptionsMenu=menu
        return menu
    end
    return options,env,channel,provider,logs
end
local options,env,channel,provider,logs=fixture()
options:tick(0)
check(not options.auto_aim and not options.seeker_homing and not options.allow_multiplayer and not options.menu,
    'missing menu keeps manual and solo defaults')
local menu=provider(true,true,true)
options:tick(0.1)
check(menu.registers==0,'registration polling throttled')
options:tick(0.25)
local aim,homing=menu.specs[Options.ID],menu.specs[Options.SEEKER_ID]
local multiplayer=menu.specs[Options.MULTIPLAYER_ID]
for _,spec in ipairs({aim,homing,multiplayer}) do
    check(spec.type=='toggle' and spec.default==false,'native toggle defaults OFF')
    check(spec.mod_id=='codex.drone_remote_control','own mod category')
end
check(options.auto_aim and options.seeker_homing and options.allow_multiplayer,'all persisted selections applied on late provider arrival')
check(aim.label()=='Auto Aim' and aim.mod()=='Drone Remote Control','English default labels')
check(homing.label()=='Seeker Homing Assist','separate Seeker guidance label')
check(multiplayer.label()=='Allow Multiplayer' and multiplayer.description():find('Default: Off'),
    'multiplayer toggle declares its solo default')
menu.callbacks[Options.ID](false)
check(not options.auto_aim and options.seeker_homing,'aim callback cannot alter Seeker mode')
menu.callbacks[Options.SEEKER_ID](false)
check(not options.seeker_homing and options.allow_multiplayer,'Seeker callback cannot change multiplayer policy')
menu.callbacks[Options.MULTIPLAYER_ID](false)
check(not options.allow_multiplayer and not options.auto_aim and not options.seeker_homing,'multiplayer callback changes only its own value')
for _,id in ipairs({Options.ID,Options.SEEKER_ID,Options.MULTIPLAYER_ID}) do
    menu.callbacks[id]('true');menu.callbacks[id](nil);menu.callbacks[id](1)
end
check(not options.auto_aim and not options.seeker_homing and not options.allow_multiplayer,'nonboolean callbacks ignored')
menu.values[Options.MULTIPLAYER_ID]=false
menu.values[Options.ID],menu.values[Options.SEEKER_ID]=false,false
options:tick(0.26)
check(menu.reads==3,'poll does not run every frame')
options:tick(0.5)
check(menu.reads==6 and menu.registers==3,'each option registers once with bounded polling')
for _,code in ipairs({'KR','KO','ko-KR','ko_kr'}) do
    channel.code=code
    check(aim.label()~='Auto Aim' and aim.label():find('[\128-\255]'),'Korean aim label uses UTF-8')
    check(homing.label()~='Seeker Homing Assist' and homing.description():find('[\128-\255]'),'Korean Seeker labels use UTF-8')
    check(multiplayer.label()~='Allow Multiplayer' and multiplayer.description():find('[\128-\255]'),'Korean multiplayer labels use UTF-8')
end
channel.code='FR'
check(aim.label()=='Auto Aim' and homing.label()=='Seeker Homing Assist' and multiplayer.label()=='Allow Multiplayer',
    'unsupported language falls back to English')
channel.code='KR'
check(aim.label()~='Auto Aim' and homing.label()~='Seeker Homing Assist','return to Korean updates both dynamically')
channel.fail=true
check(aim.label()=='Auto Aim','unavailable language falls back safely')
channel.fail=nil;channel.index=15
check(aim.label()=='Auto Aim','out-of-range language index never followed')
channel.index=nil
local old=menu
menu=provider(false,false);options:tick(0.75)
check(not options.auto_aim and not options.seeker_homing and not options.allow_multiplayer and menu.registers==3,
    'replacement provider reads all selections')
old.callbacks[Options.ID](true);old.callbacks[Options.SEEKER_ID](true);old.callbacks[Options.MULTIPLAYER_ID](true)
check(not options.auto_aim and not options.seeker_homing and not options.allow_multiplayer,'stale provider callbacks ignored')
menu.callbacks[Options.ID](true);menu.callbacks[Options.SEEKER_ID](true)
check(options.auto_aim and options.seeker_homing,'current callbacks accepted independently')
menu.fail=Options.SEEKER_ID;options:tick(1)
check(not options.auto_aim and options.seeker_homing,'one failed read does not block another option')
menu.fail=nil;menu.values[Options.SEEKER_ID]=3;options:tick(1.25)
check(options.seeker_homing,'invalid persisted value preserves last selection')
options:tick(0)
check(menu.reads==12,'clock rewind resumes all polls')
local reads=menu.reads
for _,now in ipairs({-1,0/0,math.huge}) do options:tick(now) end
check(menu.reads==reads,'invalid clock ignored')

options,env,channel,provider=fixture();menu=provider(false,true);menu.reject=Options.ID
options:tick(0);options:tick(0.25);options:tick(1.9)
check(menu.registers==3 and not options.auto_aim and options.seeker_homing,'one rejected registration backs off without blocking the others')
menu.reject=false;options:tick(2.2)
check(menu.registers==4 and menu.callbacks[Options.ID]~=nil,'registration failure recovers')
options,env,channel,provider=fixture();menu=provider(false,false);menu.version=2
options:tick(0)
check(menu.registers==0 and not options.auto_aim and not options.seeker_homing,'incompatible provider refused')
menu.version=3;menu.reject_subscription=true;options:tick(0.25)
check(next(menu.callbacks)==nil,'failed subscription is not success')
menu.reject_subscription=false;options:tick(0.5)
check(type(menu.callbacks[Options.ID])=='function' and type(menu.callbacks[Options.SEEKER_ID])=='function' and
    type(menu.callbacks[Options.MULTIPLAYER_ID])=='function','all subscriptions recover')
menu.values[Options.MULTIPLAYER_ID]=true;options:tick(0.75)
check(options.allow_multiplayer and not options.auto_aim and not options.seeker_homing,'multiplayer polling is independent of aim')
menu.values[Options.MULTIPLAYER_ID]='true';options:tick(1)
check(options.allow_multiplayer,'invalid persisted multiplayer value never changes policy')
menu.values[Options.MULTIPLAYER_ID]=false;options:tick(1.25)
check(not options.allow_multiplayer,'saved OFF restores solo-only policy')
return checks
