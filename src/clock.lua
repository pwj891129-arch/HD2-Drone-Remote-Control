local Clock = {}
function Clock.new(now)
    local clock = {}
    function clock:step()
        local current = now()
        assert(type(current) == 'number' and current == current and current >= 0 and
            current < math.huge, 'monotonic_clock_unavailable')
        local previous = self.previous
        self.previous = current
        -- Initialization, paused frames and a reset clock must not move the drone.
        if not previous or current <= previous then return 0 end
        return math.min(current - previous, 0.05)
    end
    return clock
end
return Clock
