local Guidance = {manual_hold = 0.35}
function Guidance.apply(session,input,position,target,enabled,now)
    local manual = (input.dx or 0) ~= 0 or (input.dy or 0) ~= 0
    for _,key in ipairs({'forward','back','left','right','up','down'}) do
        if input[key] ~= 0 then manual = true end
    end
    if manual then session.manual_until = now+Guidance.manual_hold end
    if not enabled or manual or now < (session.manual_until or 0) or not target then return false end
    local delta,length = {},0
    for axis = 1,3 do
        local n = target[axis]
        if type(n) ~= 'number' or n ~= n or math.abs(n) >= 100000 then return false end
        delta[axis] = n-position[axis]
        length = length+delta[axis]^2
    end
    length = math.sqrt(length)
    if length < 0.001 or length > 200 then return false end
    local yaw = session.yaw
    local x = (math.cos(yaw)*delta[1]+math.sin(yaw)*delta[2])/length
    local y = (-math.sin(yaw)*delta[1]+math.cos(yaw)*delta[2])/length
    local z = delta[3]/length
    input.right,input.left = math.max(0,x),math.max(0,-x)
    input.forward,input.back = math.max(0,y),math.max(0,-y)
    input.up,input.down = math.max(0,z),math.max(0,-z)
    return true
end
return Guidance
