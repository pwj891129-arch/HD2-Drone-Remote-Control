local source = ...
local checks = 0
local function check(value,message) assert(value,message);checks=checks+1 end
local function fixture(previous)
    local now,ticks,stops,resets = 0,{},0,0
    local controller = {status='idle',active=false,stage='snapshot'}
    function controller:tick(dt)
        ticks[#ticks+1]=dt
        if self.fail then error(self.fail) end
    end
    function controller:stop() stops=stops+1;self.active=false;self.session=nil end
    function controller:reset_inputs(preserve) resets=resets+1;self.last_preserve=preserve end
    local env = setmetatable({update=previous,shutdown=function(...)return...end,
        CowboyBingusModLoader={api=1},stingray={Unit={},World={},Window={},Mouse={},Vector3={},Quaternion={}},
        print=function()end,jit={off=function()end},
        test_channel={now=function()return now end},test_controller=controller,test_reader={stage='backpack'}},
        {__index=_G})
    env._G=env
    local chunk=assert(loadstring(source));setfenv(chunk,env);chunk()
    return env,ticks,controller,function(value)now=value end,function()return stops,resets end
end
local seen
local env,ticks,controller,time,counts=fixture(function(...)
    seen={n=select('#',...),...};return 7,nil,'tail',nil
end)
check(select('#',env.update())==4,'trailing nil returns survive no-argument update')
check(seen.n==0 and ticks[1]==0,'clock baseline ticks without callback dt')
time(0.02)
local a,b,c,d=env.update('application',nil,18)
check(a==7 and b==nil and c=='tail' and d==nil,'foreign return values preserved')
check(seen.n==3 and seen[1]=='application' and seen[2]==nil and seen[3]==18,'all callback arguments preserved')
check(math.abs(ticks[2]-0.02)<1e-8,'movement uses measured monotonic delta, not argument 1')
local option_reads=0
env.ModOptionsMenu={api=1,version=3,register_option=function(_,spec)
    check(spec.default==false,'runtime option defaults to manual aim');return true end,
    on_change=function()return true end,get=function()option_reads=option_reads+1;return true end}
time(2)
env.update(2)
check(ticks[3]==0.05 and env.DroneRemoteControl.status=='idle','long loading frame clamped, not refused')
check(option_reads==1 and controller.options.auto_aim,'late options provider uses current monotonic time')
env.update(0)
check(ticks[4]==0,'same timestamp does not produce movement')
check(option_reads==1,'runtime polls settings less often than control frames')
time(1)
env.update(nil)
check(ticks[5]==0,'clock rewind resets baseline')
check(option_reads==2,'options recover after clock rewind')
time(1.02)
env.update(500)
check(math.abs(ticks[6]-0.02)<1e-8,'clock recovers after reset')
controller.fail='map_invalid';time(1.04);env.update()
local stops,resets=counts()
check(stops==0 and resets==1 and env.DroneRemoteControl.status=='refused','idle scene error rearms input without native cleanup')
check(env.DroneRemoteControl.last_error:find('stage=snapshot/backpack'),'snapshot stage recorded')
check(controller.last_preserve==true,'passive backpack absence preserves initialized Seeker edges')
controller.pending={phase='recalling'};controller.fail='lost_rover';time(1.05);env.update()
stops,resets=counts()
check(stops==1 and resets==2,'preparation error performs cleanup even before control is active')
check(not controller.last_preserve,'pending control failures never preserve Seeker arming')
controller.pending=nil
controller.fail=nil;time(1.06);env.update()
check(env.DroneRemoteControl.last_error==nil and not env.DroneRemoteControl.stopped,'temporary error recovers next frame')
controller.active=true;controller.session={};controller.stage='control/move';controller.fail='move_failed'
time(1.08);env.update()
stops,resets=counts()
check(stops==2 and resets==3 and not env.DroneRemoteControl.control_active,'partial session restores on error')
check(env.shutdown('same')=='same' and env.DroneRemoteControl.stopped,'shutdown preserved')
local failure={}
local fail=false
env,ticks,controller,time,counts=fixture(function()if fail then error(failure)end end)
env.update()
fail=true
controller.active=true;controller.session={}
local ok,why=pcall(env.update)
stops=counts()
check(not ok and why==failure and #ticks==1 and stops==1,'foreign error object survives and control exits')
return checks
