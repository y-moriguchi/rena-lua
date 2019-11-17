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

    function me.times(minCount, maxCount, exp, execAction)
        local action = execAction or function(match, syn, inh) return inh end
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

    function me.triesTimes(minCount, maxCount, exp, nextExp, execAction)
        local action = execAction or function(match, syn, inh) return inh end
        local wrapped = me.wrap(exp)
        local nextWrapped = me.wrap(nextExp)

        return function(match, lastIndex, execAction)
            local stack = {}
            local indexNew = lastIndex
            local attrNew = attr
            local count = 0
            local ret
            while minCount and count < minCount do
                ret = wrapped(match, indexNew, attrNew)
                if ret then
                    indexNew = ret.lastIndex
                    attrNew = action(ret.match, ret.attr, attrNew)
                    count = count + 1
                else
                    return nil
                end
            end

            while not maxCount or count < maxCount do
                ret = wrapped(match, indexNew, attrNew)
                if ret then
                    stack[count] = ret
                    indexNew = ret.lastIndex
                    attrNew = action(ret.match, ret.attr, attrNew)
                    stack[count].attr = attrNew
                    count = count + 1
                else
                    break
                end
            end

            while true do
                ret = nextWrapped(match, indexNew, attrNew)
                if ret then
                    indexNew = ret.lastIndex
                    attrNew = action(ret.match, ret.attr, attrNew)
                    break
                elseif count <= minCount then
                    return nil
                else
                    count = count - 1
                    indexNew = stack[count].lastIndex
                    attrNew = stack[count].attr
                end
            end

            local result = {}
            result.match = string.sub(match, lastIndex, indexNew - 1)
            result.lastIndex = indexNew
            result.attr = attrNew
            return result
        end
    end

    function me.triesAtLeast(minCount, exp, action)
        return me.triesTimes(minCount, nil, exp, action)
    end

    function me.triesAtMost(maxCount, exp, action)
        return me.triesTimes(0, maxCount, exp, action)
    end

    function me.triesOneOrMore(exp, action)
        return me.triesTimes(1, nil, exp, action)
    end

    function me.triesZeroOrMore(exp, action)
        return me.triesTimes(0, nil, exp, action)
    end

    function me.triesMaybe(exp)
        return me.triesTimes(0, 1, exp)
    end

    function me.triesTimesNonGreedy(minCount, maxCount, exp, nextExp, execAction)
        local action = execAction or function(match, syn, inh) return inh end
        local wrapped = me.wrap(exp)
        local nextWrapped = me.wrap(nextExp)

        return function(match, lastIndex, execAction)
            local indexNew = lastIndex
            local attrNew = attr
            local count = 0
            local ret
            while minCount and count < minCount do
                ret = wrapped(match, indexNew, attrNew)
                if ret then
                    indexNew = ret.lastIndex
                    attrNew = action(ret.match, ret.attr, attrNew)
                    count = count + 1
                else
                    return nil
                end
            end

            while true do
                ret = nextWrapped(match, indexNew, attrNew)
                if ret then
                    indexNew = ret.lastIndex
                    attrNew = action(ret.match, ret.attr, attrNew)
                    break
                elseif maxCount and count >= maxCount then
                    return nil
                else
                    ret = wrapped(match, indexNew, attrNew)
                    if ret then
                        indexNew = ret.lastIndex
                        attrNew = action(ret.match, ret.attr, attrNew)
                        count = count + 1
                    else
                        return nil
                    end
                end
            end

            local result = {}
            result.match = string.sub(match, lastIndex, indexNew - 1)
            result.lastIndex = indexNew
            result.attr = attrNew
            return result
        end
    end

    function me.triesAtLeastNonGreedy(minCount, exp, action)
        return me.triesTimesNonGreedy(minCount, nil, exp, action)
    end

    function me.triesAtMostNonGreedy(maxCount, exp, action)
        return me.triesTimesNonGreedy(0, maxCount, exp, action)
    end

    function me.triesOneOrMoreNonGreedy(exp, action)
        return me.triesTimesNonGreedy(1, nil, exp, action)
    end

    function me.triesZeroOrMoreNonGreedy(exp, action)
        return me.triesTimesNonGreedy(0, nil, exp, action)
    end

    function me.triesMaybeNonGreedy(exp)
        return me.triesTimesNonGreedy(0, 1, exp)
    end

    function me.delimit(exp, delimiter, execAction)
        local action = execAction or function(match, syn, inh) return inh end
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

    function me.range(codeStart, codeEnd)
        return function(match, lastIndex, attr)
            if lastIndex >= string.len(match) then
                return nil
            end
            local codepoint = utf8.codepoint(match, lastIndex)
            if codepoint >= codeStart and codepoint <= codeEnd then
                local result = {}
                result.match = utf8.char(codepoint)
                result.lastIndex = utf8.offset(match, 2, lastIndex)
                result.attr = attr
                return result
            else
                return nil
            end
        end
    end

    function me.complement(exp)
        return function(match, lastIndex, attr)
            if lastIndex >= string.len(match) then
                return nil
            end
            local ret = exp(match, lastIndex, attr)
            if ret then
                return nil
            else
                local codepoint = utf8.codepoint(match, lastIndex)
                local result = {}
                result.match = utf8.char(codepoint)
                result.lastIndex = utf8.offset(match, 2, lastIndex)
                result.attr = attr
                return result
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

