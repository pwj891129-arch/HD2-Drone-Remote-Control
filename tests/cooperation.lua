local Cooperation = ...
local checks = 0
local function check(value,label) assert(value,label);checks=checks+1 end
local globals,state={},{}
local function peer()
    local p={input_api=1,ready=true,resume_ready=true,config={enabled=true}}
    function p.suspend_input(owner) p.owner=owner;p.calls=(p.calls or 0)+1;return p.ready end
    function p.resume_input(owner)
        check(owner==p.owner,'owner checked')
        if p.resume_error then error('temporary resume error') end
        if p.resume_ready then p.owner=nil;return true end
        return false
    end
    return p
end
local c=Cooperation.new(globals,state)
check(c:acquire() and state.blocking_inputs,'standalone acquire')
check(c:release() and not state.blocking_inputs and not state.input_owner,'standalone release')
local a,b=peer(),peer()
globals.HD2StratagemHotkeys,globals.HD2HelperAutoReload=a,b
c=Cooperation.new(globals,state)
check(c:acquire() and a.owner==b.owner,'same owner in both peers')
local token=c.owner
check(c:acquire() and c.owner==token,'idempotent acquire')
b.ready=false
check(not c:acquire() and state.blocking_inputs,'pending input release blocks capture')
b.ready=true
check(c:acquire(),'input release retry')
check(c:release() and not state.blocking_inputs,'normal release')
check(a.config.enabled and b.config.enabled,'preferences untouched')
globals.HD2HelperAutoReload={}
check(not pcall(c.acquire,c),'unsupported peer refused')
check(c:release() and not state.blocking_inputs,'partial acquire rolled back')
globals.HD2HelperAutoReload=b
c:acquire();b.resume_error=true
check(not c:release() and state.blocking_inputs,'resume error retains gate')
-- A resumed peer can see the retained gate before the next retry and reacquire it.
a.suspend_input(c.owner)
b.resume_error=false
-- Resume is idempotent in production, including already released peers.
function a.resume_input(owner) a.owner=nil;return true end
check(c:release() and not state.blocking_inputs and not a.owner and not b.owner,'all participants retried')
local late=peer();globals.HD2StratagemHotkeys=nil
c:acquire();globals.HD2StratagemHotkeys=late
check(c:acquire() and late.owner==c.owner,'late companion joins same handoff')
check(c:release() and not late.owner,'late companion released')
return checks
