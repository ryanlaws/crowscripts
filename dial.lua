-- dial marks notches in time
-- v0.0.1
-- Requires crow > 2.x
--
-- Generate pulses at voltage-controlled BPM.
-- Please see "Configuration" section below and change to taste.
--
-- In    1: BPM voltage input
-- Out 1-4: Pulses
--
-- TODO:
-- - add config
-- - do something with input 2

-- FEATURE CREEP
-- - split cycle functions (i.e. distribute phase) a la TC
-- - phasors
-- - square waves
-- - config BPM quantization


-- Configuration - customize these for sure!
local bpm_min = 60
local bpm_max = 240
local voltage_minimum = 0 -- Adjust based on voltage source
local voltage_maximum = 5

-- All fours
--local divisor = { 1, 1, 1, 1 }
--local phase = { 0, 0, 0, 0 }

-- All fours, striated
local divisor = { 1, 1, 1, 1 }
local phase = { 0/4, 3/4, 2/4, 1/4 }

-- Lab coat
--local divisor = { 1/4, 1/2, 1, 2 }
--local phase = { 0, 1/2, 1/2, 0 }

-- Sort of funky
--local divisor = { 1, 1/4, 1/2, 1 }
--local phase = { 0, 9/16, 1/2, 1/4 }

-- Reich-esque
--local divisor = { 11/29, 13/31, 17/37, 19/41 }
--local phase = { 1/3, 1/5, 1/7, 1/11 }


-- State variables - probably less fun to play with?
local bpm = 9000
local bpm_hysteresis = 1

local v_last = -20
local v_hysteresis = 0.005
local time_last = time()

function init()
    -- setup input
    input[1].stream = function (v) 
        -- check for new BPM
        if math.abs(v - v_last) > v_hysteresis then
            local new_bpm = v_to_bpm(v)
            if math.abs(bpm - new_bpm) >= bpm_hysteresis then
                bpm = new_bpm
                v_last = v -- only if action taken
                print("set bpm to " .. bpm .. " at " .. time())
            end
        end

        -- update outputs
        for_divs(accumulate, update_time(time()))
        for_divs(reconcile)
    end
    input[1].mode("stream", 0.001)

    -- setup outputs
    for_divs(function (o)
        output[o].action = pulse(0.001) 
        if phase[o] == 0 then
            output[o]() -- start right away
        end
    end)
end

function update_time(time_new)
    local time_delta = time_new - time_last
    time_last = time_new
    return time_delta
end

function for_divs(fn, arg2, arg3)
    for o = 1, math.min(#divisor, 4), 1 do
        fn(o, arg2, arg3)
    end
end

function accumulate(o, ms)
    local ms_phase_total = 1000 / (bpm / 60 * divisor[o])
    local phase_fraction = (ms / ms_phase_total)
    phase[o] = phase[o] + phase_fraction
end

function reconcile(o)
    if phase[o] >= 1 then
        output[o]() -- TODO: configure
        phase[o] = phase[o] % 1
    end
end

function v_to_bpm(v)
    v = math.min(math.max(v, voltage_minimum), voltage_maximum)
    local ratio = (v - voltage_minimum) / (voltage_maximum - voltage_minimum)
    local new_bpm = bpm_min + (ratio * (bpm_max - bpm_min))
    local frac = new_bpm % 1
    new_bpm = new_bpm - frac
    return new_bpm + (frac < 0.5 and 0 or 1)
end

