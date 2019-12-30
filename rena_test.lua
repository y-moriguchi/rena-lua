--
-- This source code is under the Unlicense
--
require 'busted.runner'()
require("rena")

function match(pattern, string, match, lastIndex)
    local result = pattern(string, 1, nil)
    assert.are.equal(result.match, match)
    assert.are.equal(result.lastIndex, lastIndex + 1)
end

function matchAttr(pattern, string, match, lastIndex, initAttr, attr)
    local result = pattern(string, 1, initAttr)
    assert.are.equal(result.match, match)
    assert.are.equal(result.lastIndex, lastIndex + 1)
    assert.are.equal(result.attr, attr)
end

function matchpos(pattern, string, startPos, match, lastIndex)
    local result = pattern(string, startPos, nil)
    assert.are.equal(result.match, match)
    assert.are.equal(result.lastIndex, lastIndex + 1)
end

function nomatch(pattern, string)
    local result = pattern(string, 1, nil)
    assert.are.equal(result, nil)
end

function nomatchpos(pattern, string, startPos)
    local result = pattern(string, startPos, nil)
    assert.are.equal(result, nil)
end

function matchAttrFn(pattern, string, match, lastIndex, attrFunction)
    local result = pattern(string, 1, nil)
    assert.are.equal(result.match, match)
    assert.are.equal(result.lastIndex, lastIndex + 1)
    assert.are.equal(attrFunction(result.attr), true)
end

function fntest(match, lastIndex, attr)
    if string.sub(match, lastIndex, lastIndex) == "a" then
        return {
            match = "a",
            lastIndex = lastIndex + 1,
            attr = attr
        }
    else
        return nil
    end
end

local r = Rena()

describe("match", function()
    it("simple match", function()
        match(r.concat("string"), "string", "string", 6)
        match(r.concat("string"), "strings", "string", 6)
        nomatch(r.concat("string"), "strin")
        match(r.concat(""), "string", "", 0)
    end)

    it("simple function match", function ()
        match(r.concat(fntest), "a", "a", 1)
        nomatch(r.concat(fntest), "s")
    end)

    it("chaining con", function ()
        local ptn = r.concat("string", "match")
        match(ptn, "stringmatch", "stringmatch", 11)
        match(ptn, "stringmatches", "stringmatch", 11)
        nomatch(ptn, "stringmatc")
        nomatch(ptn, "strinmatch")
    end)

    it("real", function ()
        local function assertReal(str, val)
            local matcher = r.real()
            assert.are.equal(matcher(str, 1, false).attr, val)
        end
        assertReal("765", 765)
        assertReal("76.5", 76.5)
        assertReal("0.765", 0.765)
        assertReal(".765", 0.765)
        assertReal("765e2", 76500)
        assertReal("765E2", 76500)
        assertReal("765e+2", 76500)
        assertReal("765e-2", 7.65)
        --assertReal("765e+346", Infinity)
        assertReal("765e-346", 0)
        nomatch(r.real(), "a961")
        assertReal("+765", 765)
        assertReal("+76.5", 76.5)
        assertReal("+0.765", 0.765)
        assertReal("+.765", 0.765)
        assertReal("+765e2", 76500)
        assertReal("+765E2", 76500)
        assertReal("+765e+2", 76500)
        assertReal("+765e-2", 7.65)
        --assertReal("+765e+346", Infinity)
        assertReal("+765e-346", 0)
        nomatch(r.real(), "+a961")
        assertReal("-765", -765)
        assertReal("-76.5", -76.5)
        assertReal("-0.765", -0.765)
        assertReal("-.765", -0.765)
        assertReal("-765e2", -76500)
        assertReal("-765E2", -76500)
        assertReal("-765e+2", -76500)
        assertReal("-765e-2", -7.65)
        --assertReal("-765e+346", -Infinity)
        assertReal("-765e-346", 0)
        nomatch(r.real(), "-a961")
    end)

    it("br", function ()
        match(r.br(), "\n", "\n", 1)
        match(r.br(), "\r", "\r", 1)
        match(r.br(), "\r\n", "\r\n", 2)
        nomatch(r.br(), "a")
    end)

    it("ending", function ()
        match(r.concat("765", r.isEnd()), "765", "765", 3)
        nomatch(r.concat("765", r.isEnd()), "765961")
        match(r.isEnd(), "", "", 0)
    end)

    it("equalsId", function ()
        local q1 = Rena({ ignore = " " })
        local q2 = Rena({ keys = {"+", "++", "-"} })
        local q3 = Rena({ ignore = " ", keys = {"+", "++", "-"} })
        match(r.equalsId("if"), "if", "if", 2)
        match(r.equalsId("if"), "if ", "if", 2)
        match(r.equalsId("if"), "iff", "if", 2)
        match(q1.equalsId("if"), "if", "if", 2)
        match(q1.equalsId("if"), "if ", "if ", 3)
        nomatch(q1.equalsId("if"), "iff")
        nomatch(q1.equalsId("if"), "if+")
        match(q2.equalsId("if"), "if", "if", 2)
        match(q2.equalsId("if"), "if+", "if", 2)
        match(q2.equalsId("if"), "if++", "if", 2)
        match(q2.equalsId("if"), "if-", "if", 2)
        nomatch(q2.equalsId("if"), "if ")
        nomatch(q2.equalsId("if"), "iff")
        match(q3.equalsId("if"), "if", "if", 2)
        match(q3.equalsId("if"), "if ", "if ", 3)
        match(q3.equalsId("if"), "if+", "if", 2)
        match(q3.equalsId("if"), "if++", "if", 2)
        match(q3.equalsId("if"), "if-", "if", 2)
        nomatch(q3.equalsId("if"), "iff")
    end)

    it("choice", function ()
        local ptn = r.choice("string", r.pegex("[0-9]+"), fntest)
        match(ptn, "string", "string", 6)
        match(ptn, "765", "765", 3)
        match(ptn, "a", "a", 1)
        nomatch(ptn, "-")
    end)

    it("opt", function ()
        match(r.opt("string"), "string", "string", 6)
        match(r.opt("string"), "strings", "string", 6)
        match(r.opt("string"), "strin", "", 0)
        match(r.opt("string"), "stringstring", "string", 6)
    end)

    it("oneOrMore", function ()
        match(r.oneOrMore("str"), "str", "str", 3)
        match(r.oneOrMore("str"), "strstrstrstrstr", "strstrstrstrstr", 15)
        nomatch(r.oneOrMore("str"), "")
    end)

    it("zeroOrMore", function ()
        match(r.zeroOrMore("str"), "", "", 0)
        match(r.zeroOrMore("str"), "str", "str", 3)
        match(r.zeroOrMore("str"), "strstrstrstrstr", "strstrstrstrstr", 15)
    end)

    it("lookahead", function ()
        match(r.concat(r.lookahead(r.pegex("[0-9]+pro")), r.pegex("[0-9]+")), "765pro", "765", 3)
        match(r.concat(r.pegex("[0-9]+"), r.lookahead("pro")), "765pro", "765", 3)
        nomatch(r.concat(r.lookahead(r.pegex("[0-9]+pro")), r.pegex("[0-9]+")), "765studio")
        nomatch(r.concat(r.pegex("[0-9]+"), r.lookahead("pro")), "765studio")
        nomatch(r.concat(r.pegex("[0-9]+"), r.lookahead("pro")), "765")
        match(r.concat(r.lookahead(r.pegex("[0-9]+pro")), r.pegex("[0-9]+")), "765pro", "765", 3)
        match(r.concat(r.pegex("[0-9]+"), r.lookahead("pro")), "765pro", "765", 3)
        nomatch(r.concat(r.pegex("[0-9]+"), r.lookahead("pro")), "765studio")
    end)

    it("lookaheadNot", function ()
        match(r.concat(r.lookaheadNot(r.pegex("[0-9]+pro")), r.pegex("[0-9]+")), "765studio", "765", 3)
        match(r.concat(r.pegex("[0-9]+"), r.lookaheadNot("pro")), "765studio", "765", 3)
        match(r.concat(r.pegex("[0-9]+"), r.lookaheadNot("pro")), "765", "765", 3)
        nomatch(r.concat(r.lookaheadNot(r.pegex("[0-9]+pro")), r.pegex("[0-9]+")), "765pro")
        nomatch(r.concat(r.pegex("[0-9]+"), r.lookaheadNot("pro")), "765pro")
        match(r.concat(r.lookaheadNot(r.pegex("[0-9]+pro")), r.pegex("[0-9]+")), "765studio", "765", 3)
    end)

    it("key", function ()
        local q = Rena({ keys = {"*", "+", "++"} })
        match(q.key("+"), "+", "+", 1)
        match(q.key("++"), "++", "++", 2)
        match(q.key("*"), "*", "*", 1)
    end)

    it("notKey", function ()
        local q = Rena({ keys = {"*", "+", "++"} })
        match(q.notKey(), "/", "", 0)
        nomatch(q.notKey(), "+")
        nomatch(q.notKey(), "++")
        nomatch(q.notKey(), "*")
    end)

    it("skip space", function ()
        local r = Rena({ ignore = r.pegex(" +") })
        match(r.concat("765", "pro"), "765pro", "765pro", 6)
        match(r.concat("765", "pro"), "765  pro", "765  pro", 8)
        nomatch(r.concat("765", "pro"), "76 5pro")
    end)

    it("letrec", function ()
        local ptn1
        local function assertParse(str)
            return ptn1(str, 1, 0)
        end

        ptn1 = r.letrec(
            function(t, f, e)
                return r.concat(f, r.zeroOrMore(r.choice(
                    r.action(r.concat("+", f), function(x, a, b) return b + a end),
                    r.action(r.concat("-", f), function(x, a, b) return b - a end))))
            end,
            function(t, f, e)
                return r.concat(e, r.zeroOrMore(r.choice(
                    r.action(r.concat("*", e), function(x, a, b) return b * a end),
                    r.action(r.concat("/", e), function(x, a, b) return b / a end))))
            end,
            function(t, f, e)
                return r.choice(r.real(), r.concat("(", t, ")"))
            end)
        assert.are.equal(assertParse("1+2*3").attr, 7)
        assert.are.equal(assertParse("(1+2)*3").attr, 9)
        assert.are.equal(assertParse("4-6/2").attr, 1)
        assert.are.equal(assertParse("1+2+3*3").attr, 12)
    end)

    it("range", function()
        match(r.range(0, 0xffff), "a", "a", 1)
        match(r.range(0, 0xffff), "カ", "カ", 3)
    end)

    it("action", function()
        local r = Rena();
        local a = r.action(r.pegex("[0-9][0-9][0-9]"), function(x, a, b) return b + tonumber(x) end);
        matchAttr(a, "765", "765", 3, 346, 1111);
    end)
end)

local function matchre(ptn, aString, matched, length)
    match(r.pegex(ptn), aString, matched, length)
end

local function nomatchre(ptn, aString, matched, length)
    nomatch(r.pegex(ptn), aString)
end

describe("pegex", function()
    it("simple elements", function()
        matchre("a", "a", "a", 1)
        nomatchre("a", "b")
    end)

    it("espace sequence (1 character)", function()
        matchre("\\n", "\n", "\n", 1)
        matchre("\\r", "\r", "\r", 1)
        matchre("\\t", "\t", "\t", 1)
        matchre("\\\\", "\\", "\\", 1)
        matchre("\\.", ".", ".", 1)
        nomatchre("\\.", "1")
    end)

    it("unicode", function()
        matchre("\\u0031", "1", "1", 1)
        matchre("\\u30a2", "ア", "ア", 3)
    end)

    it("defined character set", function()
        matchre("\\d", "0", "0", 1)
        matchre("\\d", "9", "9", 1)
        nomatchre("\\d", "/")
        nomatchre("\\d", ":")
        matchre("\\D", "/", "/", 1)
        matchre("\\D", ":", ":", 1)
        nomatchre("\\D", "0")
        nomatchre("\\D", "9")
    end)

    it("any character without newline", function()
        matchre(".", "a", "a", 1)
        nomatchre(".", "\r")
        nomatchre(".", "\n")
    end)

    it("concatate", function()
        matchre("ab", "ab", "ab", 2)
        nomatchre("ab", "ac")
        nomatchre("ab", "cb")
    end)

    it("alternation", function()
        matchre("a|b", "a", "a", 1)
        matchre("a|b", "b", "b", 1)
        nomatchre("a|b", "c")
        matchre("8765|876", "8765", "8765", 4)
        matchre("876|8765", "8765", "876", 3)
    end)

    it("repeat zero or more without backtrack", function()
        matchre("a*", "aaa", "aaa", 3)
        matchre("a*", "", "", 0)
        nomatchre(".*-", "aa-aa-aa")
    end)

    it("repeat one or more without backtrack", function()
        matchre("a+", "aaa", "aaa", 3)
        matchre("a+", "a", "a", 1)
        nomatchre("a+", "")
        nomatchre(".+-", "aa-aa-aa")
    end)

    it("optional", function()
        matchre("a?", "aaa", "a", 1)
        matchre("a?", "", "", 0)
    end)

    it("lookahead", function()
        matchre("7(?=65)", "765", "7", 1)
        nomatchre("7(?=65)", "766")
    end)

    it("lookahead negative", function()
        matchre("9(?!61)", "901", "9", 1)
        nomatchre("9(?!61)", "961")
    end)

    it("grouping", function()
        local function checkNil(attr)
            return attr[1] == nil
        end
        matchAttrFn(r.pegex("(ab)+"), "ababab", "ababab", 6, checkNil)
        matchre("(ab)+", "abbbbab", "ab", 2)
    end)

    it("starting anchor", function()
        matchre("^abc", "abc", "abc", 3)
        nomatchpos(r.pegex("^abc"), "bc", 2)
    end)

    it("ending anchor", function()
        matchre("abc$", "abc", "abc", 3)
        nomatchre("abc$", "abcd")
    end)

    it("character set 1", function()
        matchre("[bcf]", "b", "b", 1)
        matchre("[bcf]", "c", "c", 1)
        matchre("[bcf]", "f", "f", 1)
        nomatchre("[bcf]", "a")
        nomatchre("[bcf]", "d")
        nomatchre("[bcf]", "e")
        nomatchre("[bcf]", "g")
    end)

    it("character set - range", function()
        matchre("[c-x]", "c", "c", 1)
        matchre("[c-x]", "x", "x", 1)
        nomatchre("[c-x]", "b")
        nomatchre("[c-x]", "y")
        matchre("[c-eg]", "c", "c", 1)
        matchre("[c-eg]", "g", "g", 1)
        nomatchre("[c-eg]", "f")
    end)

    it("complementary character set 1", function()
        matchre("[^bcf]", "a", "a", 1)
        matchre("[^bcf]", "d", "d", 1)
        matchre("[^bcf]", "e", "e", 1)
        matchre("[^bcf]", "g", "g", 1)
        nomatchre("[^bcf]", "b")
        nomatchre("[^bcf]", "c")
        nomatchre("[^bcf]", "f")
    end)

    it("complementary character set - range", function()
        matchre("[^c-x]", "b", "b", 1)
        matchre("[^c-x]", "y", "y", 1)
        nomatchre("[^c-x]", "c")
        nomatchre("[^c-x]", "x")
    end)

    it("character set - escape", function()
        matchre("[\\n]", "\n", "\n", 1)
        nomatchre("[\\n]", "\r")
        matchre("[c\\-x]", "c", "c", 1)
        matchre("[c\\-x]", "x", "x", 1)
        matchre("[c\\-x]", "-", "-", 1)
        nomatchre("[c\\-x]", "b")
        nomatchre("[c\\-x]", "d")
        nomatchre("[c\\-x]", "w")
        nomatchre("[c\\-x]", "y")
        matchre("[a^]", "^", "^", 1)
        matchre("[\\--x]", "-", "-", 1)
        matchre("[\\--x]", "x", "x", 1)
        nomatchre("[\\--x]", "y")
    end)

    it("character set - unicode", function()
        matchre("[カ-コ]", "カ", "カ", 3)
        matchre("[カ-コ]", "コ", "コ", 3)
        nomatchre("カ-コ]", "サ")
    end)
end)

