-- this returns a random-generator function
-- to() will only generate a new voltage if it gets a function
-- this is "lazy evaluation"
function gen_rand_range(min, max, res)
    local res = res or 100
    return function ()
        return math.random((max - min) * res) / res + min
    end
end

function init()
    -- rand_range is a function
    local rand_range = gen_rand_range(-1, 2)
    output[1](loop{to(rand_range, 0.001)})
end
