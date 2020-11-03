-- dial marks notches in time
-- v0.1.0
-- Requires crow > 2.x
--
-- Generate pulses and shapes at voltage-controlled BPM.
-- Please see configure() below and change to taste.
--
-- In    1: BPM voltage input
-- Out 1-4: Pulses
--
-- TODO:
-- - do something with input 2

-- FEATURE CREEP
-- - split cycle functions (i.e. distribute phase) a la TC
-- - square waves
-- - config BPM quantization


-- ********************************************************************
-- Configuration
-- ********************************************************************
-- Ranges
-- --------------------------------------------------------------------
local bpm_min = 60
local bpm_max = 240
local bpm_quantize = 4 -- 1, 2, 4, or 10
local voltage_minimum = 0 -- Adjust based on voltage source
local voltage_maximum = 10

-- --------------------------------------------------------------------
-- Cycles (edit function body!)
-- --------------------------------------------------------------------
function configure()
    return {
        -- All fours
        --1, 1, 1, 1

        -- All fours, striated
        { 1, 0/4 },
        { 1, 3/4 },
        { 1, 2/4 },
        { 1, 1/4 }

        -- Lab coat
        --d(1/4, 0),
        --d(1/2, 1/2),
        --d(1, 1/2),
        --d(2, 0)

        -- Sort of funky (+ fatter pulses)
        --d(1  , 0   , native(pulse(0.01))),
        --d(1/4, 9/16, native(pulse(0.01))),
        --d(1/2, 1/ 2, native(pulse(0.01))),
        --d(1  , 1/ 4, native(pulse(0.01)))

        -- Reich-esque
        --{ 11/29, 1/ 3 },
        --{ 13/31, 1/ 5 },
        --{ 17/37, 1/ 7 },
        --{ 19/41, 1/11 }

        -- Barber pole
        --d(1/4, 0/4, raw(0, 5)), -- default of raw is 0v - 5v
        --d(1/4, 3/4, raw()),
        --d(1/4, 2/4, raw()),
        --d(1/4, 1/4, raw())
    }
-- ********************************************************************
end

function pinch(e, min, max) return math.min(math.max(e, min), max) end

function native(action)
    return function (o)
        output[o].action = action
        return function (new_phase, old_phase)
            if new_phase < old_phase then
                output[o]() -- threshold crossed
            end
        end
    end
end

function raw(start, finish)
    -- is validation a luxury we can afford?
    start = pinch(start or 0, -10, 10)
    finish = pinch(finish or 5, -10, 10)
    local range = finish - start
    return function (o)
        return function (phase)
            output[o].volts = start + (phase * range)
        end
    end
end

function d(divisor, phase, make_reconcile)
    make_reconcile = make_reconcile or native(pulse(0.001))
    phase = phase or 0
    divisor = divisor or 1

    local start_phase = phase

    return function (o)
        -- init
        local reconcile = make_reconcile(o)
        reconcile(phase, phase)

        return {
            function (ms, bpm) -- do phase things
                local phase_fraction = ms * bpm * divisor / 60000
                local new_phase = (phase + phase_fraction) % 1
                reconcile(new_phase, phase)
                phase = new_phase
            end,
            function (reset_phase) -- reset
                reconcile(reset_phase, phase)
                phase = reset_phase
            end
        }
    end
end

function make_update_time()
    local last = time()
    return function (new)
        local delta = new - last
        last = new
        return delta
    end
end

function v_to_bpm(v)
    v = pinch(v, voltage_minimum, voltage_maximum)
    local ratio = (v - voltage_minimum) / (voltage_maximum - voltage_minimum)
    local new_bpm = bpm_min + (ratio * (bpm_max - bpm_min))
    local frac = (new_bpm / bpm_quantize) % 1
    new_bpm = new_bpm - (frac * bpm_quantize)
    return new_bpm + ((frac < 0.5 and 0 or 1) * bpm_quantize)
end

function init()
    -- "constants"/closured utils
    local bpm_hysteresis = 1
    local v_hysteresis = 0.005
    local update_time = make_update_time()
    bpm_quantize = (
        bpm_quantize == 2 or
        bpm_quantize == 4 or
        bpm_quantize == 10
    ) and bpm_quantize or 1

    -- state
    local v_last = -20
    local bpm = 9000

    -- create the "engine"
    local divisor = configure()

    function for_divs(fn, arg2, arg3)
        for o = 1, math.min(#divisor, 4), 1 do
            fn(o, arg2, arg3)
        end
    end

    -- setup input
    input[1].stream = function (v)
        -- check for new BPM
        if math.abs(v - v_last) > v_hysteresis then
            local new_bpm = v_to_bpm(v)
            if math.abs(bpm - new_bpm) >= bpm_hysteresis then
                bpm = new_bpm
                v_last = v -- only if action taken (for now, BPM change)
            end
        end

        for_divs(
            function (o, ms) -- call phasors
                divisor[o][1](ms, bpm)
            end,
            update_time(time())
        )
    end
    input[1].mode("stream", 0.001)

    -- replace phasor-makers with actual phasors
    for_divs(function (o)
        local div = divisor[o]
        if type(div) == "number" then
            div = d(div)
        elseif type(divisor[o]) == "table" then
            div = d(div[1], div[2], div[3])
        end
        divisor[o] = div(o)
    end)
end

