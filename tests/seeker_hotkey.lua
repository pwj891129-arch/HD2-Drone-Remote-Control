local Hotkey = ...
local h = Hotkey.new()
local checks = 0
local function check(value,message) assert(value,message);checks=checks+1 end
local function step(q,fire,active,held,token)
    return h:step({aim_mode_down=q,fire_down=fire,active=active,held=held,binding_token=token or 'game-bindings'})
end
check(step(true,true,false,true)==nil,'already-held keys on load never arm')
check(step(false,false,false,true)==nil,'release rearms')
check(step(false,true,false,true)==nil,'attack alone remains a normal throw')
step(false,false,false,true)
check(step(true,false,false,true)==nil,'Q alone does not throw or control')
check(step(true,true,false,true)=='arm','hold Q then press attack reserves the held Seeker')
check(step(true,true,false,true)==nil,'holding throw input cannot repeat')
check(step(true,false,false,true)==nil,'actual throw release is not an explosion')
check(step(true,false,true,false)==nil,'takeover does not interpret held Q as cancel')
check(step(false,false,true,false)==nil,'Q release does not explode')
check(step(true,false,true,false)=='detonate','fresh Q detonates during control')
check(step(true,false,true,false)==nil,'held Q is not repeated detonation')
check(step(false,true,true,false)=='detonate','fresh attack detonates during control')
check(step(true,true,false,true,'new-bindings')==nil,'changed bindings reset edges')
step(false,false,false,false)
check(step(true,true,false,false)==nil,'other weapons cannot arm the Seeker path')
check(h:step({fire_down=true})==nil,'malformed input is refused')
h:step(nil)
check(step(true,true,false,true)==nil,'scene reset requires a new input edge')
return checks
