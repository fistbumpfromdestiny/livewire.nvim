-- In-process language server "livewire": answers textDocument/definition for Blade buffers,
-- so whatever `gd` the user has (vim.lsp.buf.definition, Snacks, Telescope) jumps to
-- components and component members. No external process; one client per project root.
local definition = require("livewire.definition")
local project = require("livewire.project")

local M = {}

M.NAME = "livewire"

--- Text of a line in a file, from its buffer when loaded.
local function line_of(file, row)
  local buf = vim.fn.bufnr(file)
  if buf > 0 and vim.api.nvim_buf_is_loaded(buf) then
    return vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  end
  local ok, lines = pcall(vim.fn.readfile, file, "", row + 1)
  return ok and lines[row + 1] or ""
end

---@param params lsp.DefinitionParams
---@return lsp.Location[]
function M.definitions(params)
  local buf = vim.uri_to_bufnr(params.textDocument.uri)
  local pos = params.position
  local line = vim.api.nvim_buf_get_lines(buf, pos.line, pos.line + 1, false)[1] or ""
  local col = vim.str_byteindex(line, "utf-16", math.min(pos.character, vim.str_utfindex(line, "utf-16")), false)
  return vim.tbl_map(function(loc)
    local character = vim.str_utfindex(line_of(loc.file, loc.row), "utf-16", loc.col, false)
    local p = { line = loc.row, character = character }
    return { uri = vim.uri_from_fname(loc.file), range = { start = p, ["end"] = p } }
  end, definition.at(buf, pos.line, col))
end

---@param dispatchers vim.lsp.rpc.Dispatchers
---@return vim.lsp.rpc.PublicClient
function M.cmd(dispatchers)
  local closing, exited, last_id = false, false, 0

  local function exit()
    closing = true
    if not exited then
      exited = true
      dispatchers.on_exit(0, 0)
    end
  end

  local handlers = {
    initialize = function()
      return { capabilities = { definitionProvider = true }, serverInfo = { name = M.NAME } }
    end,
    ["textDocument/definition"] = function(params)
      local ok, locations = pcall(M.definitions, params)
      return ok and locations or {}
    end,
    shutdown = function()
      return vim.NIL
    end,
  }

  return {
    request = function(method, params, callback, notify_reply_callback)
      last_id = last_id + 1
      local id = last_id
      local handler = handlers[method]
      vim.schedule(function()
        if handler then
          callback(nil, handler(params))
        else
          callback({ code = -32601, message = "livewire: unsupported method " .. method })
        end
        if notify_reply_callback then
          notify_reply_callback(id)
        end
      end)
      return true, id
    end,
    notify = function(method)
      if method == "exit" then
        exit()
      end
      return true
    end,
    is_closing = function()
      return closing
    end,
    terminate = exit,
  }
end

--- Attach the server to a Blade buffer inside a project.
---@param buf integer
function M.attach(buf)
  local root = project.root(buf)
  if not root or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.lsp.start({ name = M.NAME, cmd = M.cmd, root_dir = root }, { bufnr = buf })
end

--- Stop every livewire client (re-running `setup()`, or disabling the option).
function M.stop()
  for _, client in ipairs(vim.lsp.get_clients({ name = M.NAME })) do
    client:stop(true)
  end
end

return M
