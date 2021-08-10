-- * [ ] finish TT API
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
local states = {}
local ch = 1
local cmd = 20
local presets = {}
local updating = false

local bad_cmd = function (ch, value, cmd) 
    --print("don't know cmd "..cmd.."!")
end

local c2 = {}
-- | ch play @ frq      | C2 | 01-04, frq          |
c2[00] = function (ch, tt_value)
    states[ch].nte = u16_to_v10(tt_value)
    trigger_note(ch)
end
-- | ch play @ amp      | C2 | 05-08, amp (+rtrg)  |
-- | ch frq set (leg)   | C2 | 11-14, frq          |
-- | ch tmb set         | C2 | 15-18, tmb          |
    -- there is a bug w/ model 1 when pw = 16250
    -- detuned, undertones, sounds SICK
    -- DO NOT FIX IT YET
c2[14] = function (ch, v5)
    --set_state(ch, 'pw', tt_value / 16384)
    set_state(ch, 'pw', v5 / 5)
end
-- | ch env frq (Hz*10) | C2 | 21-24, Hz*10 (-lp)  |
c2[20] = function (ch, v5)
    --set_state(ch, 'efr', 2 ^ u16_to_v10(0 - tt_value))
    v5 = 2 ^ (0 - v5)
    set_state(ch, 'efr', v5)
end
-- | ch env sym (A:D)   | C2 | 25-28, sym          |
c2[24] = function (ch, v5)
    --set_state(ch, 'esy', tt_value / 16384)
    set_state(ch, 'esy', v5 / 5)
end
-- | ch env crv         | C2 | 31-34, exp          |
-- | ch env>tmb         | C2 | 35-38, dep          |
c2[34] = function (ch, v5)
    --set_state(ch, 'epw', tt_value / 16384)
    set_state(ch, 'epw', v5 / 5)
end
-- | ch env>frq         | C2 | 41-44, dep          |
c2[40] = function (ch, v5)
    --set_state(ch, 'ent', u16_to_v10(tt_value))
    set_state(ch, 'ent', v5)
end
-- | ch lfo spd (Hz*10) | C2 | 45-48, Hz*10 (+rst) |
c2[44] = function (ch, v5)
    --set_state(ch, 'lfr', 2 ^ u16_to_v10(tt_value))
    set_state(ch, 'lfr', 2 ^ v5)
end
-- | ch lfo sym (R:F)   | C2 | 51-54, sym          |
c2[50] = function (ch, v5)
    --set_state(ch, 'lsy', tt_value / 16384)
    set_state(ch, 'lsy', v5 / 5)
end
-- | ch lfo crv         | C2 | 55-58, exp          |
-- | ch lfo>tmb         | C2 | 61-64, dep          |
-- | ch lfo>frq         | C2 | 65-68, dep          |
c2[64] = function (ch, v5)
    --set_state(ch, 'lnt', u16_to_v10(tt_value))
    set_state(ch, 'lnt', v5)
end
-- | set frq slew       | C2 | 71-74, frq          |
-- | set tmb slew       | C2 | 75-78, frq          |
-- | set mod slew       | C2 | 81-84, frq          |
-- | select "engine"    | C2 | 85-88, p/s/n        |
c2[84] = function (ch, v5)
    --setup_synth(ch, tt_value)

    v5 = math.min(math.abs(v5), 5)
    setup_synth(ch, math.min(math.floor(v5 / 5 * 3) + 1), 3)
end
-- | load preset #      | C2 | 91-94, pset 0-9     |
-- | save preset #      | C2 | 95-98, pset 0-9     |

-- -32768 to 32767
function u16_to_v10(u16)
    return u16/16384*10;
end

function v10_to_u16(u16)
    return u16/10*16384;
end

function v5_to_u16(u16)
    return u16/5*16384;
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
        --local hz = v8_to_freq(v)
        -- print(v.."V = "..hz.."Hz = "..(v*12).." semitones")
        if v < 0 then
            v = v / 4.9514 * 5
        else
            v = v / 5.048 * 5
        end
        --print(((v < 0) and "" or " ")..v)

        -- print("running cmd "..cmd.." on ch "..ch.." v "..v)
        ;(c2[cmd] or bad_cmd)(ch,v,cmd)--KEEP SEMICOLON!
        for i = 1, 4 do
            if i ~= nil then
                update_synth(i)
            end
        end
        --[[if not updating then
            updating = true
            for i = 1, 4 do
                update_synth(i)
            end
            updating = false
        else
            if updating ~= -1 then
                updating = -1
                print("BYE BYE")
            end
        end--]]
    end
    input[1]{mode='stream', time=0.003}

    input[2].stream = function (v)
        collectgarbage("collect")
    end
    input[2]{mode='stream', time=10}
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

    -- a = pw2
    -- c = pw
    -- https://w.wiki/tV5
    -- m and c are relatively prime,
    -- a-1 is divisible by all prime factors of m,
    -- a-1 is divisible by 4 if m is divisible by 4.
    function lcg() return loop {
       to(dyn{        x=     1}
           : mul( dyn{pw2= 4037})
           :step( dyn{pw =21032})
           :wrap(-32768,  32768 )
                  /       32768
                  * dyn{amp=2},
          0),
       to(
           dyn{  x=1    } / 32768 * dyn{amp=2},
           dyn{cyc=1/440} / 2
       )
    } end

    states[output_index].mdl = model
    output[output_index].action = ({ var_saw, pwm, lcg })[model]()
    output[output_index]()
end

function setup_synths()
    -- var saw/tri/ramp
    setup_synth(1, 1)
    setup_synth(2, 1)
    setup_synth(3, 1)
    setup_synth(4, 1)
end

function setup_i2c()
    ii.self.call1 = function (b1)
        if b1 > 100 then
            local eng = b1 % 10
            local ch = ((b1 - eng) % 100) / 10
            print("setting ch "..ch.." to eng "..eng)
            setup_synth(ch, eng)
        else
            ch = (b1 % 10 % 4)
            ch = (ch == 0 and 4) or ch
            cmd = b1 - ch
            print("setting cmd to "..cmd.." on ch "..ch)
        end
    end
    ii.self.call2 = function (b1, x)
        ch = (b1 % 10 % 4)
        ch = (ch == 0 and 4) or ch
        cmd = b1 - ch
        --;(c2[cmd] or bad_cmd)(ch,x,cmd)--KEEP SEMICOLON!
        print("I am count dracula "..ch.." "..x.." "..cmd)
    end
    ii.self.call3 = function (ch, note, vol)
    -- | play frq, amp      | C3 | 01-04, frq, amp     |
    -- | play preset, amp   | C3 | 11-14, frq, amp     |
        if ch == nil or note == nil or vol == nil or
            ch < 1 or ch > 4 then 
            return 
        end
        --print("ch:"..ch.." note:"..note.." vol:"..vol)
        local  v8 = u16_to_v10(note)
        local amp = u16_to_v10( vol)
        --print("v8:"..v8.." amp:"..amp)
        -- too noisy for now
        -- print("C3: "..ch..", freq:"..freq..", amp:"..amp)

        states[ch].nte = v8
        states[ch].amp = amp
        -- print("triggered")
        trigger_note(ch)
        -- output[ch].dyn.amp = amp -- not yet
    end
end

function set_state(ch, key, value)
    if value ~= nil then
        states[ch][key] = value
    end
end

function setup_state(i)
    -- sy (symmetry) is like pulsewidth
    states[i] = {
        nte=0,
        amp=2,
        pw=0,
        pw2=4037,
        mdl=1,
        -- I think these are slew
        nsl=16384,
        psl=16384,
        msl=16384,
        -- this crashes when I set it negative (or 0?)

        efr=100, esy=-1, ecr=4, epw=0, ent=0, eph= 1,

        lfr=  5, lsy= 0, lcr=0, lpw=0, lnt=0, lph=-1
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
    -- print("triggered "..ch)
    -- do not retrigger attack
    if states[ch].eph >= states[ch].esy then
        states[ch].eph = -1
    end
end

function update_synth(i)
    -- can also just take a benchmark/delta
    -- but that's probably unnecessary tbh
    local s = states[i]

    -- just using input as timer, a bit hacky
    local sec = input[1].time

    -- env
    s.eph = acc(s.eph, s.efr, sec, false)
    local ampenv = peak(s.eph, s.esy, 3)
    local modenv = peak(s.eph, s.esy, 4)

    -- lfo
    s.lph = acc(s.lph, s.lfr, sec, true)
    local lfo = peak(s.lph, s.lsy, s.lcr)

    -- freq
    local note = s.nte + (modenv * s.ent) + (lfo * s.lnt)
    local freq = v8_to_freq(note)
    if freq <= 0 then freq = 0.0000000001 end
    local cyc = 1/freq
    if cyc <= 0 then cyc = 0.0000000001 end
    output[i].dyn.cyc = cyc

    -- amp
    output[i].dyn.amp = ampenv * s.amp

    -- timbre
    if s.mdl == 3 then
        --local pw = s.pw + (env * s.epw) + (lfo * s.lpw)
        --pw = math.max(-1, math.min(pw, 1))
        --pw = (pw + 1) / 2
        local pw = s.pw
        output[i].dyn.pw = math.abs(pw * 16384)
        output[i].dyn.pw2 = s.pw2
    else
        local pw = s.pw + (modenv * s.epw) + (lfo * s.lpw)
        pw = math.max(-1, math.min(pw, 1))
        pw = (pw + 1) / 2
        output[i].dyn.pw = pw
    end
end

function init ()
    updating = false

    -- sets up the synths
    for i = 1, 4 do
        setup_state(i)
    end

    setup_synths()

    output[1].dyn.amp = 5

    output[2].dyn.amp = 0.25

    output[3].dyn.amp = 0.3
    output[3].dyn.cyc = 1/2000

    setup_i2c()

    output[1]()
    output[2]()
    output[3]()

    setup_input()
end
