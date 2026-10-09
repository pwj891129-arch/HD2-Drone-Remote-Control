local Flight = {}
local function finite(n) return type(n) == 'number' and n == n and math.abs(n) < 1000000 end
function Flight.distance(a, b)
    local d = 0
    for i = 1, 3 do
        assert(finite(a[i]) and finite(b[i]), 'position_invalid')
        d = d + (a[i] - b[i]) ^ 2
    end
    return math.sqrt(d)
end
function Flight.color(d)
    if d > 90 then return {255, 235, 65, 65} end
    if d > 80 then return {255, 255, 165, 45} end
    return {255, 70, 225, 100}
end
function Flight.step(position, yaw, pitch, input, dt, velocity)
    assert(finite(dt) and dt >= 0 and dt <= 0.1, 'frame_gap')
    yaw = yaw - math.max(-300, math.min(300, input.dx or 0)) * 0.0025
    pitch = math.max(-1.45, math.min(1.45,
        pitch - math.max(-300, math.min(300, input.dy or 0)) * 0.0025))
    local x, y, z = input.right - input.left, input.forward - input.back, input.up - input.down
    local length = math.sqrt(x*x + y*y + z*z)
    local scale = length > 0 and 1 / length or 0
    local s, c = math.sin(yaw), math.cos(yaw)
    local target = {(c*x - s*y)*scale*8, (s*x + c*y)*scale*8, z*scale*8}
    velocity = velocity or {0,0,0}
    local delta, magnitude = {},0
    for i=1,3 do
        assert(finite(velocity[i]) and math.abs(velocity[i]) <= 8.001, 'velocity_invalid')
        delta[i] = target[i]-velocity[i]
        magnitude = magnitude+delta[i]*delta[i]
    end
    magnitude = math.sqrt(magnitude)
    -- Time-based thrust/braking, retaining world-space momentum while looking around.
    local fraction = magnitude > 0 and math.min(1,(length > 0 and 24 or 16)*dt/magnitude) or 0
    local next_velocity, speed = {},0
    for i=1,3 do
        next_velocity[i] = velocity[i]+delta[i]*fraction
        speed = speed+next_velocity[i]*next_velocity[i]
    end
    speed = math.sqrt(speed)
    if speed < 0.0001 then speed,next_velocity = 0,{0,0,0} end
    local command = {0,0,0,speed}
    if speed > 0 then for i=1,3 do command[i] = next_velocity[i]/speed end end
    local next_position = {position[1] + command[1]*speed*dt,
        position[2] + command[2]*speed*dt, position[3] + command[3]*speed*dt}
    local forward = {-s * math.cos(pitch), c * math.cos(pitch), math.sin(pitch)}
    local camera = {next_position[1] - forward[1] * 3,
        next_position[2] - forward[2] * 3, next_position[3] + 0.6 - forward[3] * 3}
    -- Z-up, +Y-forward engine quaternion: yaw(Z) followed by pitch(X).
    local a, b = yaw / 2, pitch / 2
    local quaternion = {math.cos(a)*math.sin(b), math.sin(a)*math.sin(b),
        math.sin(a)*math.cos(b), math.cos(a)*math.cos(b)}
    return next_position, yaw, pitch, camera, quaternion, forward, command, next_velocity
end
return Flight
