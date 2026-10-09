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
    local function provider(saved)
        local menu={api=1,version=3,registers=0,reads=0,value=saved}
        function menu.register_option(id,spec)
            check(id==Options.ID,'stable persisted option id')
            menu.registers=menu.registers+1
            if menu.reject then return false end
            menu.spec=spec;return true
        end
        function menu.get(id)
            menu.reads=menu.reads+1
            if menu.fail then error('temporary provider failure') end
            return menu.value
        end
        function menu.on_change(id,callback)
            if menu.reject_subscription then return false end
            menu.callback=callback;return true
        end
        env.ModOptionsMenu=menu
        return menu
    end
    return options,env,channel,provider,logs
end
local options,env,channel,provider,logs=fixture()
options:tick(0)
check(not options.auto_aim and not options.menu,'missing menu retains manual default')
local menu=provider(true)
options:tick(0.1)
check(menu.registers==0,'registration polling throttled')
options:tick(0.25)
check(menu.spec.type=='toggle' and menu.spec.default==false,'native toggle defaults OFF')
check(menu.spec.mod_id=='codex.drone_remote_control','own mod category')
check(options.auto_aim,'saved ON applied when provider arrives late')
check(menu.spec.label()=='Auto Aim' and menu.spec.mod()=='Drone Remote Control','English default labels')
menu.callback(false)
check(not options.auto_aim,'callback changes mode immediately')
menu.callback('true');menu.callback(nil);menu.callback(1)
check(not options.auto_aim,'nonboolean callbacks ignored')
menu.value=false
options:tick(0.26)
check(menu.reads==1,'poll does not run every frame')
options:tick(0.5)
check(menu.reads==2 and menu.registers==1,'one registration plus periodic read')
for _,code in ipairs({'KR','KO','ko-KR','ko_kr'}) do
    channel.code=code
    check(menu.spec.label()~='Auto Aim' and menu.spec.label():find('[\128-\255]'),'Korean labels use UTF-8 text')
end
channel.code='FR'
check(menu.spec.label()=='Auto Aim','unsupported language falls back to English')
channel.code='KR'
check(menu.spec.label()~='Auto Aim','return to Korean updates label dynamically')
channel.fail=true
check(menu.spec.label()=='Auto Aim','unavailable language safely falls back to English')
channel.fail=nil;channel.index=15
check(menu.spec.label()=='Auto Aim','out-of-range language index never followed')
channel.index=nil
local old=menu
menu=provider(false);options:tick(0.75)
check(not options.auto_aim and menu.registers==1,'replacement provider registered and saved value applied')
old.callback(true)
check(not options.auto_aim,'old provider callback cannot change current options')
menu.callback(true)
check(options.auto_aim,'current provider callback accepted')
menu.fail=true;options:tick(1)
check(options.auto_aim,'temporary get failure preserves valid selection')
menu.fail=nil;menu.value=3;options:tick(1.25)
check(options.auto_aim,'invalid persisted value preserves valid selection')
options:tick(0)
check(menu.reads==4,'clock rewind resumes polling')
local reads=menu.reads
for _,now in ipairs({-1,0/0,math.huge}) do options:tick(now) end
check(menu.reads==reads,'invalid clock ignored')

options,env,channel,provider=fixture();menu=provider(false);menu.reject=true
options:tick(0);options:tick(0.25);options:tick(1.9)
check(menu.registers==1 and not options.auto_aim,'failed registration backs off and keeps manual')
menu.reject=false;options:tick(2.2)
check(menu.registers==2 and menu.callback~=nil,'registration failure recovers')
options,env,channel,provider=fixture();menu=provider(false);menu.version=2
options:tick(0)
check(menu.registers==0 and not options.auto_aim,'incompatible provider refused')
menu.version=3;menu.reject_subscription=true;options:tick(0.25)
check(menu.callback==nil,'failed subscription not treated as success')
menu.reject_subscription=false;options:tick(0.5)
check(type(menu.callback)=='function','subscription retry recovers')
return checks
