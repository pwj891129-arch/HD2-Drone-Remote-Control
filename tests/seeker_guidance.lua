local Guidance,Flight = ...
local checks = 0
local function check(value,message) assert(value,message);checks = checks+1 end
local function input() return {dx=0,dy=0,forward=0,back=0,left=0,right=0,up=0,down=0} end
local session = {yaw=0}
local keys = input()
check(not Guidance.apply(session,keys,{0,0,0},{0,20,0},false,0),'default OFF leaves manual flight untouched')
check(keys.forward==0,'OFF cannot add autonomous thrust')
check(Guidance.apply(session,keys,{0,0,0},{0,20,0},true,0),'valid native target enables assist')
check(keys.forward==1 and keys.back==0,'assist points toward the target')
local _,_,_,_,_,_,command=Flight.step({0,0,0},0,0,keys,0.02,{0,0,0})
check(math.abs(command[4]-0.48)<0.00001,'assist keeps bounded inertial acceleration')
for _,key in ipairs({'forward','back','left','right','up','down','dx','dy'}) do
    keys=input();keys[key]=1
    check(not Guidance.apply(session,keys,{0,0,0},{0,20,0},true,1),'manual priority: '..key)
    check(keys[key]==1,'user input never overwritten: '..key)
end
keys=input()
check(not Guidance.apply(session,keys,{0,0,0},{0,20,0},true,1.2),'mouse/key priority held briefly after release')
check(Guidance.apply(session,keys,{0,0,0},{0,20,0},true,1.36),'assist resumes after manual override expires')
session.yaw=math.pi/2;keys=input()
check(Guidance.apply(session,keys,{0,0,0},{20,0,0},true,2),'world target converted at rotated camera yaw')
check(keys.back>0.99 and math.abs(keys.right)<0.00001,'rotated local thrust still approaches world target')
for _,target in ipairs({{0/0,0,0},{math.huge,0,0},{0,201,0},{0,0,0}}) do
    keys=input()
    check(not Guidance.apply(session,keys,{0,0,0},target,true,3),'invalid/distant/zero-length target ignored')
    check(keys.forward==0 and keys.right==0,'invalid target leaves movement neutral')
end
check(not Guidance.apply(session,input(),{0,0,0},nil,true,3),'missing target uses manual flight')
return checks
