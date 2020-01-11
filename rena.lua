--
-- This source code is under the Unlicense
--
function Rena(option)
    local me = {}

    local pegexObject = nil
    local function getPEGex()
        if not pegexObject then
            pegexObject = PEGex(me)
        end
        return pegexObject
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

    local skip = nil
    if option and option.ignore then
        skip = me.wrap(option.ignore)
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

    function me.concat(...)
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

    local function times(minCount, maxCount, exp, execAction)
        local action = execAction or function(match, syn, inh) return syn end
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

    function me.oneOrMore(exp)
        return times(1, nil, exp)
    end

    function me.zeroOrMore(exp)
        return times(0, nil, exp)
    end

    function me.opt(exp)
        return times(0, 1, exp)
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
                local chutf8 = utf8.char(codepoint)
                local result = {}
                result.match = chutf8
                result.lastIndex = lastIndex + string.len(chutf8)
                result.attr = attr
                return result
            else
                return nil
            end
        end
    end

    function me.letrec(...)
        local args = {...}
        local delays = {}
        local memo = {}
        for i = 1, #args do
            (function(i)
                delays[i] = function(match, lastIndex, attr)
                    if not memo[i] then
                        memo[i] = args[i](table.unpack(delays))
                    end
                    return memo[i](match, lastIndex, attr)
                end
            end)(i)
        end
        return delays[1]
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
                return me.concat(me.lookaheadNot(me.choice(table.unpack(lst))), key)
            else
                return me.wrap(key)
            end
        else
            return me.wrap(key)
        end
    end

    function me.notKey()
        if keys then
            return me.lookaheadNot(me.choice(table.unpack(keys)))
        else
            return me.lookaheadNot(me.concat())
        end
    end

    function me.equalsId(id)
        if not keys and not skip then
            return me.wrap(id)
        elseif keys and not skip then
            return me.concat(id, me.choice(me.isEnd(), me.lookahead(me.choice(table.unpack(keys)))))
        elseif not keys and skip then
            return me.concat(id, me.choice(me.isEnd(), me.lookahead(skip)))
        else
            return me.concat(id, me.choice(me.isEnd(), me.lookahead(skip), me.lookahead(me.choice(table.unpack(keys)))))
        end
    end

    local patternFloatString = "[\\+\\-]?([0-9]+(\\.[0-9]+)?|\\.[0-9]+)([eE][\\+\\-]?[0-9]+)?"
    local patternFloat = nil
    local function getPatternFloat()
        if not patternFloat then
            patternFloat = getPEGex().pegex(patternFloatString)
        end
        return patternFloat
    end

    function me.real()
        return function(match, lastIndex, attr)
            local ptn = getPatternFloat()
            local result = ptn(match, lastIndex, attr)
            if result then
                return {
                    match = result.match,
                    lastIndex = result.lastIndex,
                    attr = tonumber(result.match)
                }
            else
                return nil
            end
        end
    end

    local patternBr = nil
    function me.br()
        if not patternBr then
            patternBr = getPEGex().pegex("\\r\\n|\\r|\\n")
        end
        return patternBr
    end

    function PEGex(re)
        local me = {}

        local function createPEGexParser(flags)
            local function init(init, alt, con, star, element)
                local function actionInit(match, syn, inh)
                    return re.concat(re.attr({}), syn)
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
                    return re.choice(inh, syn)
                end
                return re.concat(con, re.zeroOrMore(re.action(re.concat("|", con), actionAlter)))
            end

            local function concat(init, alt, con, star, element)
                local function actionConcat(match, syn, inh)
                    if inh.star == "*" then
                        return re.concat(re.zeroOrMore(inh.exp), syn)
                    elseif inh.star == "+" then
                        return re.concat(re.oneOrMore(inh.exp), syn)
                    elseif inh.star == "?" then
                        return re.concat(re.opt(inh.exp), syn)
                    else
                        return re.concat(inh.exp, syn)
                    end
                end

                local function actionEnd(match, syn, inh)
                    return actionConcat(match, "", inh)
                end
                return re.concat(star, re.choice(re.action(re.lookahead(re.choice("|", ")", re.isEnd())), actionEnd), re.action(con, actionConcat)))
            end

            local function createNaturalNumber()
                local ch = re.range(0x30, 0x39)
                local function actionNumber(match, syn, inh)
                    local matchNum = utf8.codepoint(match, 1) - 0x30
                    return inh * 10 + matchNum
                end
                return re.concat(re.attr(0), re.oneOrMore(re.action(ch, actionNumber)))
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

                local function actionRepeatStar(match, syn, inh)
                    return {
                        star = match
                    }
                end

                local star = re.action(re.choice("*", "+", "?", ""), actionRepeatStar)
                return re.concat(element, re.action(star, actionStar))
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
                    return re.concat(re.lookaheadNot(syn), re.range(0, 0xffff))
                end

                local function actionHexDigit(match, syn, inh)
                    local codepoint = tonumber(match, 16)
                    return utf8.char(codepoint)
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
                local hexUnicode = re.concat("u", re.action(re.concat(hexDigit, hexDigit, hexDigit, hexDigit), actionHexDigit))
                local anyChar = re.choice(re.concat("\\", re.choice(matchEscChar1, hexUnicode, otherChar)), otherChar)

                local escExp = {
                    d = re.range(0x30, 0x39),
                    D = re.concat(re.lookaheadNot(re.range(0x30, 0x39)), re.range(0, 0xffff))
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
                local backslash = re.concat("\\", matchEsc)

                local lookahead = re.action(re.concat("(?=", alt, ")"), actionLookahead)
                local lookaheadNot = re.action(re.concat("(?!", alt, ")"), actionLookaheadNot)
                local paren = re.choice(lookahead, lookaheadNot, re.concat("(", alt, ")"))

                local chchset = re.concat(re.lookaheadNot("]"), anyChar)
                local chrange = re.concat(chchset, "-", re.action(chchset, actionRange))
                local ch1 = re.action(chchset, actionCh1)
                local chelem = re.choice(chrange, ch1)
                local chelems = re.concat(re.attr(nil), re.oneOrMore(re.action(chelem, actionChElems)))
                local chcmpset = re.concat("[^", re.action(chelems, actionChCmp), "]")
                local chset = re.concat("[", chelems, "]")
                local anchorStart = re.action("^", function(match, syn, inh) return re.isStart() end)
                local anchorEnd = re.action("$", function(match, syn, inh) return re.isEnd() end)
                local dot = re.action(".", function(match, syn, inh) return re.concat(re.lookaheadNot(re.choice("\r", "\n")), re.range(0, 0xffff)) end)
                local elem = re.choice(chcmpset, chset, paren, backslash, anchorStart, anchorEnd, dot, re.action(anyChar, actionChar))
                return re.concat(re.lookaheadNot("|", ")"), elem)
            end

            local parser = re.letrec(init, alter, concat, rep, element)
            return parser
        end

        local pegexParser = createPEGexParser()

        function me.pegex(pattern, flags)
            local result
            result = pegexParser(pattern, 1, nil)
            if result then
                return result.attr
            else
                return nil
            end
        end

        return me
    end

    local pegexEngine = PEGex(me)

    function me.pegex(pattern)
        return pegexEngine.pegex(pattern)
    end

    return me
end

