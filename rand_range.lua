-- this returns a random-generator function
-- to() will only generate a new voltage if it gets a function
-- this is "lazy evaluation"
function gen_rand_range(min, max, res)
    local res = res or 100
    return function ()
        return math.random((max - min) * res) / res + min
    end
end

function memo_stream(fn, initial_value)
    local last = initial_value

    function generate()
        last = fn()
        return last
    end

    function memo()
        return last
    end

    return generate, memo
end

function init()
    -- rand_range is a function
    local rand_range = gen_rand_range(0, 2, 12)
    local gen, memo = memo_stream(rand_range, 0)
    output[1](loop{to(gen, 0.1), to(memo, 0.5)})
end
