-- Livewire's `$` names: magic actions usable in `wire:click="…"` and friends, and the
-- magic properties of `$wire`.
--
-- Provenance (re-check when bumping):
--   Livewire 4: wireProperty("$…") registrations in dist/livewire.esm.js at tag v4.4.8, and
--               SupportMagicActions::$magicActions ($refresh, $set, $sync, $commit)
--   Livewire 3: docs/actions.md and docs/javascript.md at tag v3.8.11; names not confirmed
--               there are marked v4-only
-- `scripts/bundle-directives.sh <livewire.esm.js>` lists the `$wire` names a bundle defines.
local M = {}

local both, v4 = { 3, 4 }, { 4 }

---@class livewire.Magic
---@field name string Including the leading `$`
---@field versions integer[]
---@field desc string

local function magic(name, versions, desc)
  return { name = name, versions = versions, desc = desc }
end

--- Offered at the start of an action value (`wire:click="$refresh"`).
---@type livewire.Magic[]
M.actions = {
  magic("$refresh", both, "Re-render the component without calling a method"),
  magic("$set", both, "Set a property: `$set('name', value)`"),
  magic("$toggle", both, "Flip a boolean property: `$toggle('open')`"),
  magic("$parent", both, "Call a method on the parent component: `$parent.save()`"),
  magic("$dispatch", both, "Dispatch an event: `$dispatch('saved', { id: 1 })`"),
  magic("$dispatchTo", both, "Dispatch an event to another component: `$dispatchTo('cart', 'updated')`"),
  magic("$dispatchSelf", both, "Dispatch an event to this component only"),
  magic("$event", both, "The browser event that triggered the action"),
  magic("$js", both, "Run a JavaScript action defined with `$js` or `#[Js]`"),
  magic("$commit", both, "Send pending updates to the server"),
}

--- Offered after `$wire.`.
---@type livewire.Magic[]
M.wire = {
  magic("$get", both, "Read a property: `$wire.$get('name')`"),
  magic("$set", both, "Set a property: `$wire.$set('name', value)`"),
  magic("$toggle", both, "Flip a boolean property"),
  magic("$call", both, "Call a method by name: `$wire.$call('save')`"),
  magic("$refresh", both, "Re-render the component"),
  magic("$commit", both, "Send pending updates to the server"),
  magic("$entangle", both, "Share a property with Alpine state"),
  magic("$watch", both, "Run a callback when a property changes"),
  magic("$on", both, "Listen for an event"),
  magic("$dispatch", both, "Dispatch an event"),
  magic("$dispatchTo", both, "Dispatch an event to another component"),
  magic("$dispatchSelf", both, "Dispatch an event to this component only"),
  magic("$el", both, "The component's root element"),
  magic("$id", both, "The component's id"),
  magic("$parent", both, "The parent component's `$wire`"),
  magic("$js", both, "JavaScript actions defined on the component"),
  magic("$upload", both, "Upload a file to a property"),
  magic("$uploadMultiple", both, "Upload several files to a property"),
  magic("$removeUpload", both, "Remove an uploaded file from a property"),
  magic("$cancelUpload", both, "Cancel an upload in progress"),
  magic("$hook", v4, "Register a lifecycle hook"),
  magic("$errors", v4, "The component's validation errors"),
  magic("$dirty", v4, "Whether a property has unsent changes: `$wire.$dirty('name')`"),
  magic("$refs", v4, "Elements marked with `wire:ref`"),
  magic("$island", v4, "Render an island: `$wire.$island('stats')`"),
  magic("$intercept", v4, "Intercept actions and requests"),
  magic("$dispatchEl", v4, "Dispatch an event from an element"),
  magic("$dispatchRef", v4, "Dispatch an event from a `wire:ref` element"),
}

---@param list livewire.Magic[]
---@param version integer
---@return livewire.Magic[]
function M.for_version(list, version)
  return vim.tbl_filter(function(m)
    return vim.tbl_contains(m.versions, version)
  end, list)
end

return M
