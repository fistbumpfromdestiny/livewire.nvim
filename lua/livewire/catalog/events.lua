-- DOM events usable as `wire:<event>`. Livewire forwards any `wire:` name it doesn't handle
-- itself to Alpine as `x-on:<name>` (js/directives/wire-wildcard.js), so these all work.
local M = {}

local both, v4 = { 3, 4 }, { 4 }

--- Shown in completion. Everything in `names` is valid; these are the ones worth suggesting.
M.common = {
  click = "Call a component method when the element is clicked",
  submit = "Call a component method when the form is submitted (prevents the default submit)",
  keydown = "Call a component method on key down; add key modifiers such as `.enter`",
  keyup = "Call a component method on key up; add key modifiers such as `.enter`",
  change = "Call a component method when the value is committed",
  input = "Call a component method on every input",
  blur = "Call a component method when the element loses focus",
  focus = "Call a component method when the element gains focus",
  dblclick = "Call a component method on double click",
  mouseenter = "Call a component method when the pointer enters the element",
  mouseleave = "Call a component method when the pointer leaves the element",
}

-- stylua: ignore
local names = {
  -- mouse / pointer
  "click", "dblclick", "auxclick", "contextmenu", "mousedown", "mouseup", "mousemove", "mouseenter",
  "mouseleave", "mouseover", "mouseout", "wheel", "pointerdown", "pointerup", "pointermove",
  "pointerenter", "pointerleave", "pointerover", "pointerout", "pointercancel",
  "gotpointercapture", "lostpointercapture",
  -- touch
  "touchstart", "touchend", "touchmove", "touchcancel",
  -- keyboard
  "keydown", "keyup", "keypress",
  -- focus
  "focus", "blur", "focusin", "focusout",
  -- form
  "input", "change", "submit", "reset", "invalid", "select", "beforeinput", "search",
  "formdata",
  -- clipboard / composition
  "copy", "cut", "paste", "compositionstart", "compositionupdate", "compositionend",
  -- drag and drop
  "drag", "dragstart", "dragend", "dragenter", "dragleave", "dragover", "drop",
  -- media
  "play", "pause", "playing", "ended", "seeked", "seeking", "timeupdate", "volumechange",
  "loadeddata", "loadedmetadata", "canplay", "canplaythrough", "waiting", "stalled",
  "durationchange", "ratechange", "emptied", "suspend", "progress",
  -- resources / elements
  "load", "error", "abort", "scroll", "scrollend", "resize", "toggle", "beforetoggle",
  "close", "cancel", "animationstart", "animationend", "animationiteration",
  "transitionstart", "transitionend", "transitionrun", "transitioncancel",
  "fullscreenchange", "fullscreenerror", "selectionchange", "slotchange",
}

---@type table<string, true>
M.names = {}
for _, name in ipairs(names) do
  M.names[name] = true
end

--- Events whose modifiers include free-form key names (`.enter`, `.shift`, `.arrow-up`, ...).
M.keyboard = { keydown = true, keyup = true, keypress = true }

---@type livewire.Modifier[]
M.modifiers = {
  { name = "prevent", versions = both, desc = "Call `event.preventDefault()`" },
  { name = "stop", versions = both, desc = "Call `event.stopPropagation()`" },
  { name = "self", versions = both, desc = "Only fire when the event target is the element itself" },
  { name = "once", versions = both, desc = "Only fire the first time" },
  { name = "window", versions = both, desc = "Listen on `window` instead of the element" },
  { name = "document", versions = both, desc = "Listen on `document` instead of the element" },
  { name = "outside", versions = both, desc = "Fire when the event happens outside the element" },
  { name = "away", versions = both, desc = "Alias of `.outside`" },
  { name = "passive", versions = both, desc = "Register a passive listener" },
  { name = "capture", versions = both, desc = "Listen in the capture phase" },
  { name = "camel", versions = both, desc = "Listen for the camelCase version of the event name" },
  { name = "dot", versions = both, desc = "Turn dashes in the event name into dots" },
  { name = "debounce", versions = both, arg = "ms", desc = "Debounce the handler (default 250ms), e.g. `.debounce.500ms`" },
  { name = "throttle", versions = both, arg = "ms", desc = "Throttle the handler (default 250ms), e.g. `.throttle.500ms`" },
  { name = "async", versions = v4, desc = "Run the action in parallel instead of queueing it" },
  { name = "renderless", versions = v4, desc = "Skip re-rendering the component after the action" },
  { name = "preserve-scroll", versions = v4, desc = "Keep the scroll position when the component re-renders" },
  { name = "prepend", versions = v4, desc = "Prepend the rendered island instead of replacing it" },
  { name = "append", versions = v4, desc = "Append the rendered island instead of replacing it" },
}

--- Alpine key modifiers offered after `wire:keydown.` and friends. Any kebab-cased
--- `KeyboardEvent.key` is also valid, so these are suggestions, not a whitelist.
-- stylua: ignore
M.keys = {
  "enter", "escape", "esc", "space", "tab", "backspace", "delete",
  "up", "down", "left", "right", "arrow-up", "arrow-down", "arrow-left", "arrow-right",
  "home", "end", "page-up", "page-down",
  "shift", "ctrl", "alt", "meta", "cmd", "super", "caps-lock",
  "slash", "period", "comma", "equal", "minus", "underscore",
}

return M
