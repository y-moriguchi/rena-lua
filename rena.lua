function Rena(option)
    local me = {}

    local skip = nil
    if option and option.ignore then
        skip = option.ignore
    end

    local function skipSpace(match, index)
        if skip then
            local ret = skip(match, index, nil)
            if ret then
                return ret.lastIndex
            else
                return index
            end
        else
            return index
        end
    end

    local function matchString(obj, match, lastIndex, attr)
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

    function me.wrap(obj)
        if type(obj) == "string" then
            return function(match, lastIndex, attr)
                return matchString(obj, match, lastIndex, attr)
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
                    indexNew = skipSpace(match, ret.lastIndex)
                    attrNew = ret.attr
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

    function me.choiceSelect(selector, ...)
        local args = {...}
        return function(match, lastIndex, attr)
            local results = {}
            for i = 1, #args do
                local ret = (me.wrap(args[i]))(match, lastIndex, attr)
                table.insert(results, ret)
            end
            return selector(table.unpack(results))
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
                    indexNew = skipSpace(match, ret.lastIndex)
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

        return function(match, lastIndex, attr)
            local stack = {}
            local indexNew = lastIndex
            local attrNew = attr
            local count = 0
            local ret

            while minCount and count < minCount do
                ret = wrapped(match, indexNew, attrNew)
                if ret then
                    indexNew = skipSpace(match, ret.lastIndex)
                    attrNew = action(ret.match, ret.attr, attrNew)
                    count = count + 1
                else
                    return nil
                end
            end

            while not maxCount or count < maxCount do
                stack[count] = {}
                stack[count].lastIndex = indexNew
                stack[count].attr = attrNew
                ret = wrapped(match, indexNew, attrNew)
                if ret then
                    indexNew = skipSpace(match, ret.lastIndex)
                    attrNew = action(ret.match, ret.attr, attrNew)
                    count = count + 1
                else
                    break
                end
            end

            while true do
                ret = nextWrapped(match, indexNew, attrNew)
                if ret then
                    indexNew = skipSpace(match, ret.lastIndex)
                    attrNew = action(ret.match, ret.attr, attrNew)
                    break
                elseif count < minCount then
                    return nil
                else
                    indexNew = stack[count].lastIndex
                    attrNew = stack[count].attr
                    count = count - 1
                end
            end

            local result = {}
            result.match = string.sub(match, lastIndex, indexNew - 1)
            result.lastIndex = indexNew
            result.attr = attrNew
            return result
        end
    end

    function me.triesAtLeast(minCount, exp, nextExp, action)
        return me.triesTimes(minCount, nil, exp, nextExp, action)
    end

    function me.triesAtMost(maxCount, exp, nextExp, action)
        return me.triesTimes(0, maxCount, exp, nextExp, action)
    end

    function me.triesOneOrMore(exp, nextExp, action)
        return me.triesTimes(1, nil, exp, nextExp, action)
    end

    function me.triesZeroOrMore(exp, nextExp, action)
        return me.triesTimes(0, nil, exp, nextExp, action)
    end

    function me.triesMaybe(exp, nextExp)
        return me.triesTimes(0, 1, exp, nextExp)
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
                    indexNew = skipSpace(match, ret.lastIndex)
                    attrNew = action(ret.match, ret.attr, attrNew)
                    count = count + 1
                else
                    return nil
                end
            end

            while true do
                ret = nextWrapped(match, indexNew, attrNew)
                if ret then
                    indexNew = skipSpace(match, ret.lastIndex)
                    attrNew = action(ret.match, ret.attr, attrNew)
                    break
                elseif maxCount and count >= maxCount then
                    return nil
                else
                    ret = wrapped(match, indexNew, attrNew)
                    if ret then
                        indexNew = skipSpace(match, ret.lastIndex)
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

    function me.triesAtLeastNonGreedy(minCount, exp, nextExp, action)
        return me.triesTimesNonGreedy(minCount, nil, exp, nextExp, action)
    end

    function me.triesAtMostNonGreedy(maxCount, exp, nextExp, action)
        return me.triesTimesNonGreedy(0, maxCount, exp, nextExp, action)
    end

    function me.triesOneOrMoreNonGreedy(exp, nextExp, action)
        return me.triesTimesNonGreedy(1, nil, exp, nextExp, action)
    end

    function me.triesZeroOrMoreNonGreedy(exp, nextExp, action)
        return me.triesTimesNonGreedy(0, nil, exp, nextExp, action)
    end

    function me.triesMaybeNonGreedy(exp, nextExp)
        return me.triesTimesNonGreedy(0, 1, exp, nextExp)
    end

    function me.delimit(exp, delimiter, execAction)
        local action = execAction or function(match, syn, inh) return inh end
        local wrapped = me.wrap(exp)
        local wrappedDelimiter = me.wrap(delimiter)
        return me.con(me.action(wrapped, action), me.zeroOrMore(me.con(wrappedDelimiter, me.action(wrapped, action))))
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

    function me.isStart()
        return function(match, lastIndex, attr)
            if lastIndex == 1 then
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

    function me.isEnd()
        return function(match, lastIndex, attr)
            if lastIndex > string.len(match) then
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

    function me.action(exp, action)
        local wrapped = me.wrap(exp)
        return function(match, lastIndex, attr)
            local result = wrapped(match, lastIndex, attr)
            if result then
                result.match = result.match
                result.lastIndex = result.lastIndex
                result.attr = action(result.match, result.attr, attr)
                return result
            else
                return nil
            end
        end
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
            if lastIndex > string.len(match) then
                return nil
            end
            local codepoint = utf8.codepoint(match, lastIndex)
            if codepoint >= codeStart and codepoint <= codeEnd then
                local result = {}
                result.match = utf8.char(codepoint)
                result.lastIndex = utf8.offset(match, lastIndex) + 1
                result.attr = attr
                return result
            else
                return nil
            end
        end
    end

    function me.complement(exp)
        return function(match, lastIndex, attr)
            if lastIndex > string.len(match) then
                return nil
            end
            local ret = exp(match, lastIndex, attr)
            if ret then
                return nil
            else
                local codepoint = utf8.codepoint(match, lastIndex)
                local result = {}
                result.match = utf8.char(codepoint)
                result.lastIndex = utf8.offset(match, lastIndex) + 1
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

    local keys = nil
    local keysBin = {}
    local keysBinMax = 0
    if option and option.keys then
        keys = option.keys
        for i = 1, #keys do
            local klen = string.len(keys[i])
            if keysBin[klen] == nil then
                keysBin[klen] = {}
            end
            table.insert(keysBin[klen], keys[i])
            if keysBinMax < klen then
                keysBinMax = klen
            end
        end
    end

    function me.key(key)
        if keys then
            local lst = {}
            for i = string.len(key) + 1, keysBinMax do
                for j = 1, #(keysBin[i]) do
                    if key == string.sub(keysBin[i][j], 1, string.len(key)) then
                        table.insert(lst, keysBin[i][j])
                    end
                end
            end
            if #lst > 0 then
                return me.con(me.lookaheadNot(me.choice(table.unpack(lst))), key)
            else
                return me.wrap
            end
        else
            return me.wrap
        end
    end

    function me.notKey()
        if keys then
            return me.lookaheadNot(me.choice(table.unpack(keys)))
        else
            return me.lookaheadNot(me.con())
        end
    end

    return me
end

function Regex()
    local me = {}
    local re = Rena()

    local function createRegexParser(flags)
        local function init(init, alt, con, star, element)
            local function actionInit(match, syn, inh)
                return re.con(re.attr({}), syn)
            end
            return re.action(alt, actionInit)
        end

        local function alter(init, alt, con, star, element)
            local function selector(arg1, arg2)
                if not arg1 and not arg2 then
                    return nil
                elseif not arg1 then
                    return arg2
                elseif not arg2 then
                    return arg1
                elseif arg1.lastIndex < arg2.lastIndex then
                    return arg2
                else
                    return arg1
                end
            end

            local function actionAlter(match, syn, inh)
                if flags == "M" then
                    return re.choiceSelect(selector, inh, syn)
                else
                    return re.choice(inh, syn)
                end
            end
            return re.con(con, re.zeroOrMore(re.con("|", con), actionAlter))
        end

        local function concat(init, alt, con, star, element)
            local function actionCon(match, syn, inh)
                if inh.star == "*" then
                    return re.triesZeroOrMore(inh.exp, syn)
                elseif inh.star == "+" then
                    return re.triesOneOrMore(inh.exp, syn)
                elseif inh.star == "?" then
                    return re.triesMaybe(inh.exp, syn)
                elseif inh.star == "*?" then
                    return re.triesZeroOrMoreNonGreedy(inh.exp, syn)
                elseif inh.star == "+?" then
                    return re.triesOneOrMoreNonGreedy(inh.exp, syn)
                elseif inh.star == "??" then
                    return re.triesMaybeNonGreedy(inh.exp, syn)
                elseif inh.star == "*+" then
                    return re.con(re.zeroOrMore(inh.exp), syn)
                elseif inh.star == "++" then
                    return re.con(re.oneOrMore(inh.exp), syn)
                elseif inh.star == "?+" then
                    return re.con(re.maybe(inh.exp), syn)
                elseif inh.star == "}" then
                    return re.triesTimes(inh.repeatStart, inh.repeatEnd, inh.exp, syn)
                elseif inh.star == "}?" then
                    return re.triesTimesNonGreedy(inh.repeatStart, inh.repeatEnd, inh.exp, syn)
                elseif inh.star == "}+" then
                    return re.con(re.times(inh.repeatStart, inh.repeatEnd, inh.exp), syn)
                else
                    return re.con(inh.exp, syn)
                end
            end

            local function actionEnd(match, syn, inh)
                return actionCon(match, "", inh)
            end
            return re.con(star, re.choice(re.action(re.lookahead(re.choice("|", ")", re.isEnd())), actionEnd), re.action(con, actionCon)))
        end

        local function createNaturalNumber()
            local ch = re.range(0x30, 0x39)
            local function actionNumber(match, syn, inh)
                local matchNum = utf8.codepoint(match, 1) - 0x30
                return inh * 10 + matchNum
            end
            return re.con(re.attr(0), re.oneOrMore(ch, actionNumber))
        end
        local naturalNumber = createNaturalNumber()

        local function rep(init, alt, con, star, element)
            local function actionStar(match, syn, inh)
                return {
                    star = syn.star,
                    repeatStart = syn.repeatStart,
                    repeatEnd = syn.repeatEnd,
                    exp = inh
                }
            end

            local function actionRepeat(match, syn, inh)
                return {
                    repeatStart = inh,
                    repeatEnd = syn,
                }
            end

            local function actionAtLeast(match, syn, inh)
                return {
                    repeatStart = syn,
                    repeatEnd = nil,
                }
            end

            local function actionTimes(match, syn, inh)
                return {
                    repeatStart = syn,
                    repeatEnd = syn,
                }
            end

            local function actionSpecifier(match, syn, inh)
                return {
                    star = match,
                    repeatStart = inh.repeatStart,
                    repeatEnd = inh.repeatEnd
                }
            end

            local function actionRepeatStar(match, syn, inh)
                return {
                    star = match
                }
            end

            local specifier = re.action(re.choice("}?", "}+", "}"), actionSpecifier)
            local rep = re.con("{", naturalNumber, ",", re.action(naturalNumber, actionRepeat), specifier)
            local atLeast = re.con("{", re.action(naturalNumber, actionAtLeast), ",", specifier)
            local times = re.con("{", re.action(naturalNumber, actionTimes), specifier)
            local star = re.action(re.choice("*?", "+?", "??", "*+", "++", "?+", "*", "+", "?", ""), actionRepeatStar)
            local reps = re.choice(rep, atLeast, times, star)
            return re.con(element, re.action(reps, actionStar))
        end

        local function element(init, alt, con, star, element)
            local function actionChar(match, syn, inh)
                return re.wrap(syn)
            end

            local function actionRange(match, syn, inh)
                local codeStart = utf8.codepoint(inh, 1)
                local codeEnd = utf8.codepoint(syn, 1)
                return re.range(codeStart, codeEnd)
            end

            local function actionCh1(match, syn, inh)
                return re.wrap(syn)
            end

            local function actionChElems(match, syn, inh)
                if inh == nil then
                    return syn
                else
                    return re.choice(inh, syn)
                end
            end

            local function actionChCmp(match, syn, inh)
                return re.con(re.lookaheadNot(syn), re.range(0, 0xffff))
            end

            local function actionCapture(match, syn, inh)
                local function innerAction(match, syn, inh)
                    local copy = {}
                    for key, value in pairs(syn) do
                        copy[key] = value
                    end
                    table.insert(copy, match)
                    return copy
                end
                return re.action(syn, innerAction)
            end

            local function actionHexDigit(match, syn, inh)
                local codepoint = tonumber(match, 16)
                return utf8.char(codepoint)
            end

            local function actionRefer(match, syn, inh)
                local function matchCapture(matchInner, lastIndex, attr)
                    local num = utf8.codepoint(match, 1) - 0x30
                    if attr[num] == nil then
                        error("uncaputured number")
                    end
                    return matchString(attr[num], matchInner, lastIndex, attr)
                end
                return matchCapture
            end

            local function actionAny(match, syn, inh)
                return re.wrap(match)
            end

            local function actionLookahead(match, syn, inh)
                return re.lookahead(syn)
            end

            local function actionLookaheadNot(match, syn, inh)
                return re.lookaheadNot(syn)
            end

            local escExpChar1 = {
                n = "\n",
                r = "\r",
                t = "\t"
            }
            escExpChar1["\\"] = re.wrap("\\")
            local function matchEscChar1(match, lastIndex, attr)
                local escCh = string.sub(match, lastIndex, lastIndex)
                local escResult = escExpChar1[escCh]
                if escResult == nil then
                    return nil
                else
                    return {
                        match = escCh,
                        lastIndex = lastIndex + 1,
                        attr = escResult
                    }
                end
            end
            local otherChar = re.action(re.range(0, 0xffff), function(match, syn, inh) return match end)
            local hexDigit = re.choice(re.range(0x30, 0x39), re.range(0x41, 0x46), re.range(0x61, 0x66))
            local hexUnicode = re.con("u", re.action(re.con(hexDigit, hexDigit, hexDigit, hexDigit), actionHexDigit))
            local anyChar = re.choice(re.con("\\", re.choice(matchEscChar1, hexUnicode, otherChar)), otherChar)

            local escExp = {
                d = re.range(0x30, 0x39),
                D = re.con(re.lookaheadNot(re.range(0x30, 0x39)), re.range(0, 0xffff))
            }
            local function matchEsc(match, lastIndex, attr)
                local escCh = string.sub(match, lastIndex, lastIndex)
                local escResult = escExp[escCh]
                if escResult == nil then
                    return nil
                else
                    return {
                        match = escCh,
                        lastIndex = lastIndex + 1,
                        attr = escResult
                    }
                end
            end
            local refer = re.action(re.range(0x30, 0x39), actionRefer)
            local bsSec = re.choice(matchEsc, refer)
            local backslash = re.con("\\", bsSec)

            local lookahead = re.action(re.con("(?=", alt, ")"), actionLookahead)
            local lookaheadNot = re.action(re.con("(?!", alt, ")"), actionLookaheadNot)
            local capture = re.action(re.con("(", alt, ")"), actionCapture)
            local paren = re.choice(re.con("(?:", alt, ")"), lookahead, lookaheadNot, capture)

            local chchset = re.con(re.lookaheadNot("]"), anyChar)
            local chrange = re.con(chchset, "-", re.action(chchset, actionRange))
            local ch1 = re.action(chchset, actionCh1)
            local chelem = re.choice(chrange, ch1)
            local chelems = re.con(re.attr(nil), re.oneOrMore(chelem, actionChElems))
            local chcmpset = re.con("[^", re.action(chelems, actionChCmp), "]")
            local chset = re.con("[", chelems, "]")
            local anchorStart = re.action("^", function(match, syn, inh) return re.isStart() end)
            local anchorEnd = re.action("$", function(match, syn, inh) return re.isEnd() end)
            local elem = re.choice(chcmpset, chset, paren, backslash, anchorStart, anchorEnd, re.action(anyChar, actionChar))
            return re.con(re.lookaheadNot("|", ")"), elem)
        end

        local parser = re.letrec(init, alter, concat, rep, element)
        return parser
    end

    local regexParser = createRegexParser()
    local regexParserMax = createRegexParser("M")

    function me.regex(pattern, flags)
        local result
        if flags == "M" then
            result = regexParserMax(pattern, 1, nil)
        else
            result = regexParser(pattern, 1, nil)
        end
        if result then
            return result.attr
        else
            return nil
        end
    end

    local function matchPos(matcher, dest, position)
        while position <= string.len(dest) do
            local result = matcher(dest, position, nil)
            if result then
                result.attr[0] = result.match
                result.attr.lastIndex = result.lastIndex - 1
                result.attr.index = position
                return result.attr
            else
                position = position + 1
            end
        end
        return nil
    end

    function me.global(pattern, flags)
        local matcher = me.regex(pattern, flags)

        local function matchFirst(dest)
            local position = 1
            local function matchNext()
                local result = matchPos(matcher, dest, position)
                if result then
                    position = result.lastIndex
                end
                return result
            end
            return matchNext
        end
        return matchFirst
    end

    function me.matcher(pattern, flags)
        local matcher = me.regex(pattern, flags)

        local function matchFirst(dest)
            return matchPos(matcher, dest, 1)
        end
        return matchFirst
    end

    function me.split(pattern, flags)
        local matcher = me.global(pattern, flags)

        local function splitString(dest)
            local matchNext = matcher(dest)
            local splitted = {}
            local indexBefore = 1
            while true do
                local result = matchNext()
                if result then
                    table.insert(splitted, string.sub(dest, indexBefore, result.index - 1))
                else
                    table.insert(splitted, string.sub(dest, indexBefore, string.len(dest)))
                    return splitted
                end
                indexBefore = result.lastIndex + 1
            end
        end
        return splitString
    end

    return me
end

