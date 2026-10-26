-- Livewire `wire:` directives.
--
-- Provenance (re-check when bumping):
--   Livewire 4: dist/livewire.esm.js and docs/ at tag v4.4.8
--   Livewire 3: dist/livewire.esm.js and docs/ at tag v3.8.11
-- `scripts/bundle-directives.sh <livewire.esm.js>` lists what a bundle handles.
--
-- Docs paths are relative to https://livewire.laravel.com/docs/<major>.x/.
-- DOM events (`wire:click`, ...) live in events.lua.

---@alias livewire.ArgKind "ms"|"duration"|"number"|"length"|string[]

---@class livewire.Modifier
---@field name string
---@field versions integer[]
---@field desc string
---@field arg? livewire.ArgKind Kind of the optional segment(s) following this modifier
---@field arg_max? integer How many argument segments may follow (default 1)

---@class livewire.Subname
---@field name string
---@field versions integer[]
---@field desc string

---@class livewire.Directive
---@field name string
---@field versions integer[]
---@field desc string
---@field docs string|table<integer, string>
---@field modifiers livewire.Modifier[]
---@field subnames? livewire.Subname[]|"any"
---@field bare_arg? livewire.ArgKind A modifier-position argument with no modifier name (`wire:poll.5s`)

local both, v3, v4 = { 3, 4 }, { 3 }, { 4 }

local function mod(name, versions, desc, arg, arg_max)
  return { name = name, versions = versions, desc = desc, arg = arg, arg_max = arg_max }
end

--- Modifiers shared by wire:loading, wire:dirty and wire:offline (js/directives/shared.js).
local function toggle_modifiers(state)
  return {
    mod("remove", both, "Show the element by default and hide it " .. state),
    mod("class", both, "Add the classes in the value " .. state .. " (`.class.remove` removes them)"),
    mod("attr", both, "Add the attribute named in the value " .. state),
    mod("inline", both, "Use `display: inline` when shown"),
    mod("block", both, "Use `display: block` when shown"),
    mod("inline-flex", both, "Use `display: inline-flex` when shown"),
    mod("flex", both, "Use `display: flex` when shown"),
    mod("grid", both, "Use `display: grid` when shown"),
    mod("table", both, "Use `display: table` when shown"),
    mod("list-item", both, "Use `display: list-item` when shown"),
  }
end

local function extend(list, more)
  return vim.list_extend(vim.deepcopy(list), more)
end

local delay_levels = { "shortest", "shorter", "short", "default", "long", "longer", "longest", "none" }

---@type livewire.Directive[]
return {
  {
    name = "model",
    versions = both,
    desc = "Bind an input's value to a component property",
    docs = "wire-model",
    modifiers = {
      mod("live", both, "Send updates to the server as the value changes (debounced 150ms)"),
      mod("blur", both, "Update on blur"),
      mod("change", both, "Update on change"),
      mod("enter", v4, "Update when Enter is pressed"),
      mod("lazy", both, "Update on change and send a network request (v3 behaviour)"),
      mod("defer", v3, "Livewire 2 leftover; accepted and ignored by Livewire 3"),
      mod("debounce", both, "Debounce network updates, e.g. `.live.debounce.500ms`", "ms"),
      mod("throttle", both, "Throttle network updates, e.g. `.live.throttle.500ms`", "ms"),
      mod("number", both, "Cast the value to `int` on the server"),
      mod("boolean", both, "Cast the value to `bool` on the server"),
      mod("fill", both, "Use the element's initial `value` attribute"),
      mod("trim", both, "Trim whitespace from the value"),
      mod("deep", v4, "Also listen to input events from child elements"),
      mod("renderless", v4, "Skip re-rendering after a live update"),
      mod("preserve-scroll", v4, "Keep the scroll position when the component re-renders"),
    },
  },
  {
    name = "loading",
    versions = both,
    desc = "Show or change the element while a network request is in flight",
    docs = "wire-loading",
    modifiers = extend(toggle_modifiers("during loading"), {
      mod("delay", both, "Wait before showing (200ms, or `.delay.shortest` … `.delay.longest`)", delay_levels),
    }),
  },
  {
    name = "target",
    versions = both,
    desc = "Limit `wire:loading` to specific actions or properties",
    docs = { [3] = "wire-loading#targeting-specific-actions", [4] = "wire-loading#targeting-specific-actions" },
    modifiers = { mod("except", both, "Show loading for every request except these targets") },
  },
  {
    name = "dirty",
    versions = both,
    desc = "Show or change the element while client state differs from the server",
    docs = "wire-dirty",
    modifiers = toggle_modifiers("while dirty"),
  },
  {
    name = "offline",
    versions = both,
    desc = "Show or change the element while the browser is offline",
    docs = "wire-offline",
    modifiers = toggle_modifiers("while offline"),
  },
  {
    name = "poll",
    versions = both,
    desc = "Refresh the component, or call a method, on an interval (default 2.5s)",
    docs = "wire-poll",
    bare_arg = "duration",
    modifiers = {
      mod("keep-alive", both, "Keep polling while the tab is in the background"),
      mod("visible", both, "Only poll while the element is in the viewport"),
    },
  },
  {
    name = "init",
    versions = both,
    desc = "Call a method as soon as the component is rendered on the page",
    docs = "wire-init",
    modifiers = {},
  },
  {
    name = "confirm",
    versions = both,
    desc = "Ask the user to confirm before running the action",
    docs = "wire-confirm",
    modifiers = { mod("prompt", both, "Require typing an expected value: `\"Message|expected\"`") },
  },
  {
    name = "navigate",
    versions = both,
    desc = "Load the link's page with SPA-style navigation",
    docs = "wire-navigate",
    modifiers = {
      mod("hover", both, "Prefetch the page on hover"),
      mod("preserve-scroll", both, "Keep the scroll position after navigating"),
    },
    subnames = {
      { name = "scroll", versions = v4, desc = "Preserve this element's scroll position across page visits" },
    },
  },
  {
    name = "scroll",
    versions = v3,
    desc = "Preserve this element's scroll position across page visits",
    docs = { [3] = "navigate#preserving-scroll-position" },
    modifiers = {},
  },
  {
    name = "current",
    versions = both,
    desc = "Add the classes in the value when the link points to the current page",
    docs = "wire-current",
    modifiers = {
      mod("exact", both, "Only match the exact path"),
      mod("strict", both, "Match trailing slashes too"),
      mod("ignore", both, "Never mark this link as current"),
    },
  },
  {
    name = "ignore",
    versions = both,
    desc = "Keep Livewire from updating this element and its children",
    docs = "wire-ignore",
    modifiers = {
      mod("self", both, "Only ignore the element's own attributes, not its children"),
      mod("children", both, "Only ignore the children, not the element itself"),
    },
  },
  {
    name = "replace",
    versions = both,
    desc = "Replace children on update instead of morphing them",
    docs = "wire-replace",
    modifiers = { mod("self", both, "Replace the element itself as well as its children") },
  },
  {
    name = "cloak",
    versions = both,
    desc = "Hide the element until Livewire has initialised",
    docs = "wire-cloak",
    modifiers = {},
  },
  {
    name = "key",
    versions = both,
    desc = "Give the element a stable identity for DOM diffing (use in loops)",
    docs = { [3] = "components#adding-wirekey-to-foreach-loops", [4] = "troubleshooting#adding-wirekey" },
    modifiers = {},
  },
  {
    name = "stream",
    versions = both,
    desc = "Receive content streamed from the server with `$this->stream()`",
    docs = "wire-stream",
    modifiers = { mod("replace", both, "Replace the content instead of appending to it") },
  },
  {
    name = "transition",
    versions = both,
    desc = "Animate the element when it is shown, hidden or changed",
    docs = "wire-transition",
    modifiers = {
      mod("in", v3, "Only transition in"),
      mod("out", v3, "Only transition out"),
      mod("opacity", v3, "Only fade"),
      mod("scale", v3, "Only scale (optionally to a percentage, e.g. `.scale.80`)", "number"),
      mod("duration", v3, "Transition duration, e.g. `.duration.200ms`", "ms"),
      mod("delay", v3, "Transition delay, e.g. `.delay.50ms`", "ms"),
      mod("origin", v3, "Transform origin, e.g. `.origin.top.left`", { "top", "bottom", "left", "right" }, 2),
      mod("navigate", v4, "Transition between page visits instead of component updates"),
    },
  },
  {
    name = "show",
    versions = both,
    desc = "Toggle the element's visibility from a component expression, without a request",
    docs = "wire-show",
    modifiers = { mod("important", both, "Hide with `display: none !important`") },
  },
  {
    name = "text",
    versions = both,
    desc = "Set the element's text from a component expression, without a request",
    docs = "wire-text",
    modifiers = {},
  },
  {
    name = "bind",
    versions = v4,
    desc = "Bind an HTML attribute to a component expression: `wire:bind:<attribute>`",
    docs = "wire-bind",
    modifiers = {},
    subnames = "any",
  },
  {
    name = "ref",
    versions = v4,
    desc = "Name the element (or child component) so it can be targeted with `$refs`",
    docs = "wire-ref",
    modifiers = {},
  },
  {
    name = "island",
    versions = v4,
    desc = "Scope this element's action to the named island",
    docs = "islands",
    modifiers = {
      mod("append", v4, "Append the island's new content"),
      mod("prepend", v4, "Prepend the island's new content"),
    },
  },
  {
    name = "intersect",
    versions = v4,
    desc = "Call an action when the element enters (or leaves) the viewport",
    docs = "wire-intersect",
    modifiers = {
      mod("once", v4, "Only fire on the first intersection"),
      mod("half", v4, "Fire when half of the element is visible"),
      mod("full", v4, "Fire when all of the element is visible"),
      mod("threshold", v4, "Fire at a visibility percentage, e.g. `.threshold.50`", "number"),
      mod("margin", v4, "Grow the viewport, e.g. `.margin.200px` or `.margin.10%`", "length", 4),
      mod("dwell", v4, "Require continuous visibility first (default 250ms)", "ms"),
      mod("parent", v4, "Observe within the parent element instead of the viewport"),
      mod("renderless", v4, "Run the action without re-rendering"),
      mod("async", v4, "Run the action in a parallel request"),
      mod("preserve-scroll", v4, "Keep the scroll position through the action"),
    },
    subnames = {
      { name = "enter", versions = v4, desc = "Fire when the element enters the viewport (default)" },
      { name = "leave", versions = v4, desc = "Fire when the element leaves the viewport" },
    },
  },
  {
    name = "sort",
    versions = v4,
    desc = "Make children drag-and-drop sortable and call a method with the new order",
    docs = "wire-sort",
    modifiers = {
      mod("async", v4, "Run the action in a parallel request"),
      mod("renderless", v4, "Run the action without re-rendering"),
      mod("prepend", v4, "Prepend the island's new content"),
      mod("append", v4, "Append the island's new content"),
    },
    subnames = {
      { name = "item", versions = v4, desc = "Mark a sortable item; the value is its key" },
      { name = "handle", versions = v4, desc = "Only allow dragging by this handle" },
      { name = "ignore", versions = v4, desc = "Don't start a drag from this element" },
      { name = "group", versions = v4, desc = "Allow dragging between lists in the same group" },
      { name = "group-id", versions = v4, desc = "Identify this list within its group" },
      { name = "config", versions = v4, desc = "Pass SortableJS options" },
    },
  },
}
