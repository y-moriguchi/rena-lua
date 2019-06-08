function Rena()
    local me = {}

    function me.wrap(obj)
        if type(obj) == "string" then
            return function(match, lastIndex, attr)
                if lastIndex + string.len(obj) - 1 > string.len(match) then
                    return nil
                end
                local dest = string.sub(match, lastIndex, lastIndex + string.len(obj) - 1)
                if dest == obj then
                    local result = {}
                    result.match = dest
                    result.lastIndex = lastIndex + string.len(dest)
                    result.attr = attr
                    return result
                else
                    return nil
                end
            end
        else
            return obj
        end
    end

    function me.con(...)
        local args = {...}
        return function(match, lastIndex, attr)
            local indexNew = lastIndex
            local attrNew = attr
            for i = 1, #args do
                local ret = (me.wrap(args[i]))(match, indexNew, attrNew)
                if ret then
                    indexNew = ret.lastIndex
                    attrNew = ret.attrNew
                else
                    return nil
                end
            end
            local result = {}
            result.match = string.sub(match, lastIndex, indexNew - 1)
            result.lastIndex = indexNew
            result.attr = attrNew
            return result
        end
    end

    function me.choice(...)
        local args = {...}
        return function(match, lastIndex, attr)
            for i = 1, #args do
                local ret = (me.wrap(args[i]))(match, lastIndex, attr)
                if ret then
                    return ret
                end
            end
            return nil
        end
    end

    function me.times(minCount, maxCount, exp, action)
        local action = action or function(match, syn, inh) return inh end
        local wrapped = me.wrap(exp)
        return function(match, lastIndex, attr)
            local indexNew = lastIndex
            local attrNew = attr
            local count = 0
            while not maxCount or count < maxCount do
                local ret = wrapped(match, indexNew, attrNew)
                if ret then
                    indexNew = ret.lastIndex
                    attrNew = action(ret.match, ret.attr, attrNew)
                    count = count + 1
                elseif count < minCount then
                    return nil
                else
                    break
                end
            end
            local result = {}
            result.match = string.sub(match, lastIndex, indexNew - 1)
            result.lastIndex = indexNew
            result.attr = attrNew
            return result
        end
    end

    function me.atLeast(minCount, exp, action)
        return me.times(minCount, nil, exp, action)
    end

    function me.atMost(maxCount, exp, action)
        return me.times(0, maxCount, exp, action)
    end

    function me.oneOrMore(exp, action)
        return me.times(1, nil, exp, action)
    end

    function me.zeroOrMore(exp, action)
        return me.times(0, nil, exp, action)
    end

    function me.maybe(exp)
        return me.times(0, 1, exp)
    end

    function me.delimit(exp, delimiter, action)
        local action = action or function(match, syn, inh) return inh end
        local wrapped = me.wrap(exp)
        local wrappedDelimiter = me.wrap(delimiter)
        return function(match, lastIndex, attr)
            local indexNew = lastIndex
            local attrNew = attr
            local indexLoop = lastIndex
            while true do
                local ret = wrapped(match, indexLoop, attrNew)
                if ret then
                    indexNew = ret.lastIndex
                    attrNew = action(ret.match, ret.attr, attrNew)
                    local retDelimiter = wrappedDelimiter(match, indexNew, attrNew)
                    if retDelimiter then
                        indexLoop = retDelimiter.lastIndex
                    else
                        break
                    end
                elseif indexNew == lastIndex then
                    return nil
                else
                    break
                end
            end
            local result = {}
            result.match = string.sub(match, lastIndex, indexNew - 1)
            result.lastIndex = indexNew
            result.attr = attrNew
            return result
        end
    end

    local function lookahead(exp, signum)
        local wrapped = me.wrap(exp)
        return function(match, lastIndex, attr)
            local ret = wrapped(match, lastIndex, attr)
            if (ret and signum) or (not ret and not signum) then
                local result = {}
                result.match = ''
                result.lastIndex = lastIndex
                result.attr = attr
                return result
            else
                return nil
            end
        end
    end

    function me.lookahead(exp)
        return lookahead(exp, true)
    end

    function me.lookaheadNot(exp)
        return lookahead(exp, false)
    end

    function me.attr(attrNew)
        return function(match, lastIndex, attr)
            local result = {}
            result.match = ''
            result.lastIndex = lastIndex
            result.attr = attrNew
            return result
        end
    end

    function me.cond(cond)
        return function(match, lastIndex, attr)
            if cond(attr) then
                local result = {}
                result.match = ''
                result.lastIndex = lastIndex
                result.attr = attr
                return result
            else
                return nil
            end
        end
    end

    function me.letrec(...)
        local args = {...}
        local function f(g) return g(g) end
        local function h(p)
            local res = {}
            for i = 1, #args do
                res[i] = function(match, lastIndex, attr)
                    return (args[i](table.unpack(p(p))))(match, lastIndex, attr)
                end
            end
            return res
        end
        return (f(h))[1]
    end

    return me
end

