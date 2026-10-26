#!/usr/bin/env bash
# List what a Livewire JS bundle knows about `wire:` attributes, to cross-check
# lua/livewire/catalog/directives.lua against a Livewire release.
#
#   scripts/bundle-directives.sh path/to/vendor/livewire/livewire/dist/livewire.esm.js
set -eu

bundle=${1:?usage: $0 path/to/livewire.esm.js}
[[ -r $bundle ]] || { echo "cannot read $bundle" >&2; exit 1; }

# CSS selectors in the bundle escape `:` and `.` (`[wire\\:sort\\:item]`); undo that.
normalized=$(sed -E 's/\\+([:.])/\1/g' "$bundle")

section() { printf '\n== %s\n' "$1"; }

section "Livewire directive registrations: directive(\"…\") / globalDirective(\"…\")"
# Alpine plugin registrations (Alpine27.directive("mask", …)) are indented and prefixed, so
# anchoring at column 0 keeps only Livewire's own.
grep -oE '^(directive|globalDirective)\("[a-z-]+"' <<<"$normalized" |
  sed -E 's/.*\("([a-z-]+)"/\1/' | sort -u | paste -sd' '

section "Directives handled by attribute prefix: startsWith(\"wire:…\")"
grep -oE 'startsWith\("wire:[a-z:-]+' <<<"$normalized" |
  sed -E 's/.*"wire:([a-z:-]+)/\1/; s/:$//' | sort -u | paste -sd' '

section "Event wildcard exclusions (never forwarded to x-on)"
grep -A3 '^// js/directives/wire-wildcard.js' <<<"$normalized" |
  grep -oE '\[("[a-z-]+",? ?)+\]' | head -1

section "Every wire: attribute literal (with sub-names and modifiers)"
# `[^a-z]` keeps `livewire:navigated` (an event name) out.
grep -oE '(^|[^a-z])wire:[a-z][a-z-]*([:.][a-z0-9][a-z0-9-]*)*' <<<"$normalized" | sed -E 's/^[^w]//' | sort -u | paste -sd' '

section "Colon sub-names"
grep -oE '(^|[^a-z])wire:[a-z-]+:[a-z][a-z-]*' <<<"$normalized" | sed -E 's/^[^w]//' | sort -u | paste -sd' '

section "Modifiers checked, by Livewire source file"
awk '
  /^\/\/ js\// { sec = $2 }
  /^\/\/ node_modules\// || /^\/\/ packages\// { sec = "" }
  sec != "" {
    line = $0
    while (match(line, /modifiers\.(includes|indexOf)\("[a-z0-9.-]+"\)/)) {
      m = substr(line, RSTART, RLENGTH); sub(/.*\("/, "", m); sub(/"\)/, "", m)
      if (!seen[sec SUBSEP m]++) mods[sec] = mods[sec] " " m
      line = substr(line, RSTART + RLENGTH)
    }
  }
  END { for (s in mods) print s ":" mods[s] }
' <<<"$normalized" | sort
