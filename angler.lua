-- angler shuffles scales
-- Requires crow > 2.x
--
-- This quantizes the input voltage to a chord. After a certain number of
-- different notes or octaves, the chord mutates. The mutation may consist of
-- adding or removing a note to/from the scale.
--
-- Input  1: Raw Voltage input
-- Output 1: Quantized output
-- Output 2: Trigger (on each new quantized voltage)
--
-- TODO: 
-- - Add "drama" control to input 2
-- - Add second output (drama-controlled offset? split?)

local scale = {1,2,3,5,6,8,9,11}
local chord = {0,4,7,10}

local max_note_chg = 40
local max_oct_chg = 8

local min_chord_size = 2
local max_chord_size = 6

local oct_jump_thresh = 10

function draw(t1, t2)
    local n = math.random(1, #t1)

    table.insert(t2, t1[n])
    table.remove(t1, n)
    table.sort(t1)
    table.sort(t2)
end

function init()
    local last_note = nil
    local note_chg = 0

    local last_oct = nil
    local oct_chg = 0

    function add() draw(scale, chord) end
    function del() draw(chord, scale) end

    function mutate()
        if #chord <= min_chord_size then 
            add() 
        elseif #chord >= max_chord_size then 
            del() 
        else
            local actions = { add, del }
            actions[math.random(1, 2)]()
        end

        input[1].mode('scale', chord)
        print(table.concat(chord, ' '))
    end

    input[1].mode('scale', chord)
    output[2].action = pulse()

    input[1].scale = function (e) 
        if e.oct ~= last_oct then
            oct_chg = oct_chg + 1
            last_oct = e.oct
        end

        note_chg = (note_chg or 0) + 1

        if oct_chg > max_oct_chg or note_chg > max_note_chg then
            mutate()
            note_chg = 0
            oct_chg = 0
        end

        local oct_jump = math.random(0, 12) > oct_jump_thresh and math.random(1, 2) or 0
        output[1].volts = e.volts + oct_jump
        output[2]()
    end
end

