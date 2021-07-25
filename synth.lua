-- just do positive for now to avoid math.sign
-- also avoid min/max... just validate in client lolol
--
--
--TODO:
-- * [ ] make param control structure (1-10ms period)
--   * [x] envelopes
--   * [x] VCAs/LPGs
--   * [ ] slew
--   * [ ] presets??
-- * [ ] make TT API
--DONE:
-- * [x] write volt -> freq convertor
local states = {}

-- -32768 to 32767
function u16_to_v(u16)
    return u16/16384*10;
end

function v8_to_freq(v8)
    -- Tyler's Mordax said JF 0V = 261.61
    -- -5v - +5v = 8.17Hz - 8.37kHz.
  return 261.61 * (2 ^ v8)
end

function setup_input()
    print("INPUT OK.")

    input[1].stream = function (v)
        -- local new = 1/((v+6) * 4000) -- time
        local v = v8_to_freq(v)

        for i = 1, 4 do
            update_synth(i)
        end
    end

    input[1]{mode='stream', time=0.001}
end

function setup_synth(output_index, model)
    function var_saw () return loop {
        to(  dyn{amp=2}, dyn{cyc=1/440} *    dyn{pw=1/2} ),
        to(0-dyn{amp=2}, dyn{cyc=1/440} * (1-dyn{pw=1/2}))
    } end

    function pwm () return loop {
       to(  dyn{amp=2},                              0  ),
       to(  dyn{amp=2}, dyn{cyc=1/440} *    dyn{pw=1/2} ),
       to(0-dyn{amp=2},                              0  ),
       to(0-dyn{amp=2}, dyn{cyc=1/440} * (1-dyn{pw=1/2}))
    } end

    function lcg() return loop {
       to(dyn{        x=     1}
           : mul( dyn{a=  -559})
           :step( dyn{c= 21032})
           :wrap(-32768, 32768 )
                  /      32768
                  * dyn{amp=2},
          0),
       to(
           dyn{  x=1    } / 32768 * dyn{amp=2},
           dyn{cyc=1/440} / 2
       )
    } end

    states[output_index].mdl = model
    output[output_index].action = ({ var_saw, pwm, lcg })[model]()
end

function setup_synths()
    -- var saw/tri/ramp
    setup_synth(1, 2)
    setup_synth(2, 2)
    setup_synth(3, 3)
    setup_synth(4, 3)
end

function setup_i2c()
    ii.self.call2 = function (cmd, value)
        --[[
| desc               | fn | ...args             |
|--------------------|----|---------------------|
| ch play            | C1 | 01-04               |
| ch play @ amp      | C2 | 05-08, amp (+rtrg)  |
| ch frq set (leg)   | C2 | 11-14, frq          |
| ch tmb set         | C2 | 15-18, tmb          |
| ch env sym (A:D)   | C2 | 25-28, sym          |
| ch env crv         | C2 | 31-34, exp          |
| ch env>tmb         | C2 | 35-38, dep          |
| ch env>frq         | C2 | 41-44, dep          |
| ch lfo spd (Hz*10) | C2 | 45-48, Hz*10 (+rst) |
| ch lfo sym (R:F)   | C2 | 51-54, sym          |
| ch lfo crv         | C2 | 55-58, exp          |
| ch lfo>tmb         | C2 | 61-64, dep          |
| ch lfo>frq         | C2 | 65-68, dep          |
| set frq slew       | C2 | 71-74, frq          |
| set tmb slew       | C2 | 75-78, frq          |
| set mod slew       | C2 | 81-84, frq          |
| select "engine"    | C2 | 85-88, p/s/n        |
| load preset #      | C2 | 91-94, pset 0-9     |
| save preset #      | C2 | 95-98, pset 0-9     |
| play frq, amp      | C3 | 01-04, frq, amp     |
| play preset, amp   | C3 | 11-14, frq, amp     |
        --]]
        -- print('raw cmd: '..cmd)
        local ch = (cmd % 10 % 4)
        ch = (ch == 0 and 4) or ch
        cmd = cmd - ch
        print('ch:'..ch..' cmd:'..cmd..' val:'..value)
        if cmd  < 00 then
            print("negative command???")

        -- | ch play @ frq      | C2 | 01-04, frq          |
        elseif cmd == 00 then
            note = u16_to_v(value)
            print("ch "..ch.." play @ note "..note)
            trigger_note(ch)

        -- | ch tmb set         | C2 | 15-18, tmb          |
        elseif cmd == 14 then
            set_state(ch, 'efr', value / 100)
        -- | ch env frq (Hz*10) | C2 | 21-24, Hz*10 (-lp)  |
        elseif cmd == 20 then
            -- TODO: handle negative values (loop?)
            value = math.abs(value)
            -- print ("env->freq: "..value / 100)
            set_state(ch, 'efr', value / 100)

        -- | ch env>frq         | C2 | 41-44, dep          |
        elseif cmd == 40 then
            local v = u16_to_v(value)
            -- print ("env->v8: "..v)
            set_state(ch, 'ent', v)

        -- | ch lfo spd (Hz*10) | C2 | 45-48, Hz*10 (+rst) |
        elseif cmd == 44 then
            value = math.abs(value)
            -- print ("env->freq: "..value / 100)
            set_state(ch, 'lfr', value / 100)

        -- | ch lfo>frq         | C2 | 65-68, dep          |
        elseif cmd == 64 then
            local v = u16_to_v(value)
            -- print ("lfo->v8: "..v)
            set_state(ch, 'lnt', v)

        -- | select "engine"    | C2 | 85-88, p/s/n        |
        elseif cmd == 84 then
            setup_synth(ch, value)

        else
            print("unknown command "..cmd)
        end
    end
    ii.self.call3 = function (ch, note, vol)
        local  v8 = u16_to_v(note)
        local amp = u16_to_v( vol)
        -- too noisy for now
        -- print("C3: "..ch..", freq:"..freq..", amp:"..amp)

        states[ch].nte = v8
        states[ch].amp = amp
        trigger_note(ch)
        -- output[ch].dyn.amp = amp -- not yet
    end
end

function set_state(ch, key, value)
    states[ch][key] = value
end

function setup_state(i)
    -- sy (symmetry) is like pulsewidth
    states[i] = {
        nte=0,
        amp=2,
        pw=0,
        mdl=1,
        -- I think these are slew
        nsl=16384,
        psl=16384,
        msl=16384,
        -- this crashes when I set it negative (or 0?)
        efr=100,
        esy=-1,
        ecr=4,
        epw=0,
        ent=2,
        eph=1,

        lfr=20,
        lsy=0,
        lcr=0,
        lpw=0,
        lnt=1,
        lph=-1
    }
    print("setting up state "..i)
    print("state #"..i..": "..states[i].nte)
end

-- assume ph and pw btw {-1..1} incl
function peak(ph, pw, curve)
    local value = (ph < pw) and ((1 + ph) / (1 + pw))
        or (ph > pw) and ((1 - ph) / (1 - pw))
        or 1

    value = value ^ (2 ^ curve)
    return value
end

function acc(phase, freq, sec, looping)
    phase = phase + (freq * sec)
    phase = looping and ((1 + phase) % 2 - 1)
        or math.min(1, phase)
    return phase
end

function trigger_note(ch)
    states[ch].eph = -1
end

function update_synth(i)
    -- can also just take a benchmark/delta
    -- but that's probably unnecessary tbh
    local s = states[i]

    -- just using input as timer, a bit hacky
    local sec = input[1].time

    -- env
    s.eph = acc(s.eph, s.efr, sec, false)
    local env = peak(s.eph, s.esy, s.ecr)

    -- lfo
    s.lph = acc(s.lph, s.lfr, sec, true)
    local lfo = peak(s.lph, s.lsy, s.lcr)

    -- freq
    local note = s.nte + (env * s.ent) + (lfo * s.lnt)
    local freq = v8_to_freq(note)
    if freq == 0 then freq = 0.0000000001 end
    local cyc = 1/freq
    if cyc == 0 then cyc = 0.0000000001 end
    output[i].dyn.cyc = cyc

    -- amp
    output[i].dyn.amp = env * s.amp

    -- timbre
    if s.mdl ~= 3 then
        local pw = s.pw + (env * s.epw) + (lfo * s.lpw)
        pw = math.max(-1, math.min(pw, 1))
        pw = (pw + 1) / 2
        output[i].dyn.pw = pw
    end

end

function init ()
    -- sets up the synths
    for i = 1, 4 do
        setup_state(i)
    end

    setup_synths()

    output[1].dyn.amp = 1

    output[2].dyn.amp = 0.25

    output[3].dyn.amp = 0.3
    output[3].dyn.cyc = 1/2000

    setup_i2c()

    output[1]()
    output[2]()
    output[3]()

    setup_input()
end
