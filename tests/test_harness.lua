local H = require("helpers")
local T = MiniTest.new_set()

T["blade parser"] = function()
  H.skip_without_blade()
  MiniTest.expect.equality(H.has_blade(), true)
end

return T
