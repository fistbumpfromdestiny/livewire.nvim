local H = require("helpers")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      vim.cmd("silent! %bwipeout!")
    end,
    post_case = function()
      require("livewire.lsp").stop()
      vim.wait(1000, function()
        return #vim.lsp.get_clients({ name = "livewire" }) == 0
      end)
    end,
  },
})

local function open(path)
  vim.cmd.edit(vim.fn.fnameescape(H.app .. "/" .. path))
  vim.bo.filetype = "blade"
  return vim.api.nvim_get_current_buf()
end

local function client(buf)
  vim.wait(1000, function()
    return #vim.lsp.get_clients({ bufnr = buf, name = "livewire" }) > 0
  end)
  return vim.lsp.get_clients({ bufnr = buf, name = "livewire" })[1]
end

T["attached to Blade buffers with the definition capability"] = function()
  require("livewire").setup({})
  local buf = open("resources/views/livewire/greeter.blade.php")
  local c = client(buf)
  eq(c ~= nil, true)
  eq(c.server_capabilities.definitionProvider, true)
  eq(c.server_capabilities.completionProvider, nil)
  eq(c.root_dir, H.app)
  -- one client per root
  local other = open("resources/views/pages/⚡profile.blade.php")
  eq(client(other).id, c.id)
end

T["answers textDocument/definition"] = function()
  H.skip_without_blade()
  require("livewire").setup({})
  local buf = open("resources/views/livewire/greeter.blade.php")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "<livewire:greeter />", '<input wire:model="name">' })
  local id = client(buf).id
  local function definition(line, character)
    local res = vim.lsp.buf_request_sync(buf, "textDocument/definition", {
      textDocument = { uri = vim.uri_from_bufnr(buf) },
      position = { line = line, character = character },
    }, 2000)
    return res[id].result
  end
  local tag = definition(0, 12)
  eq(#tag, 1)
  eq(vim.uri_to_fname(tag[1].uri), H.app .. "/app/Livewire/Greeter.php")
  eq(tag[1].range.start, { line = 0, character = 0 })
  if H.has_php() then
    local member = definition(1, 21)
    eq(vim.uri_to_fname(member[1].uri), H.app .. "/app/Livewire/Greeter.php")
    eq(member[1].range.start, { line = 13, character = 19 })
  end
  eq(definition(1, 2), {})
end

T["not started when disabled"] = function()
  require("livewire").setup({ definition = { enabled = false } })
  local buf = open("resources/views/livewire/greeter.blade.php")
  vim.wait(200)
  eq(#vim.lsp.get_clients({ bufnr = buf, name = "livewire" }), 0)
end

T["setup() again replaces the client"] = function()
  require("livewire").setup({})
  local buf = open("resources/views/livewire/greeter.blade.php")
  local first = client(buf).id
  require("livewire").setup({})
  vim.wait(1000, function()
    local c = vim.lsp.get_clients({ bufnr = buf, name = "livewire" })[1]
    return c ~= nil and c.id ~= first
  end)
  local clients = vim.lsp.get_clients({ name = "livewire" })
  eq(#clients, 1)
  eq(clients[1].id ~= first, true)
end

return T
