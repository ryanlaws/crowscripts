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
        print('raw cmd: '..cmd)
        local ch = (cmd % 10 % 4) 
        ch = (ch == 0 and 4) or ch
        cmd = cmd - ch
        print('channel: '..ch..' .. cmd w/o channel: '..cmd)
        if cmd  < 00 then
            print("negative command???")
        elseif cmd == 00 then
            note = u16_to_v(value)
            print("ch "..ch.." play @ note "..note)
            trigger_note(ch)
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
    states[i] = { 
        nte=0,  amp=2, pw1=0, mdl=1,
        nsl=16384, psl=16384, msl=16384,
        -- sy (symmetry) is like pulsewidth
        efr=100, esy=-1, ecr=4, ep1=0, ent=2, eph=1,
        lfr=20, lsy=0, lcr=0, lp1=0, lnt=1, lph=-1,
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
    local cyc = 1/freq
    output[i].dyn.cyc = cyc

    -- amp
    output[i].dyn.amp = env * s.amp

    -- timbre
    if s.mdl ~= 3 then
        local pw = s.pw1 + (env * s.ep1) + (lfo * s.lp1)
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
