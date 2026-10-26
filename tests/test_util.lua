local util = require("livewire.util")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T["distance"] = function()
  eq(util.distance("model", "model"), 0)
  eq(util.distance("modle", "model"), 1) -- transposition
  eq(util.distance("lve", "live"), 1)
  eq(util.distance("", "abc"), 3)
end

T["suggest"] = function()
  eq(util.suggest("modle", { "loading", "model", "poll" }), "model")
  eq(util.suggest("lve", { "live", "blur", "lazy" }), "live")
  eq(util.suggest("itme", { "item", "handle", "group" }), "item")
  eq(util.suggest("xyzzy", { "model", "loading", "click" }), nil)
end

T["short words need a closer match"] = function()
  eq(util.suggest("ab", { "abcd" }), nil)
  eq(util.suggest("abcdef", { "abcdxy" }), "abcdxy")
end

return T
