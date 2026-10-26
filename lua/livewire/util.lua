local M = {}

--- Optimal string alignment distance (Damerau–Levenshtein with adjacent transpositions).
---@param a string
---@param b string
---@return integer
function M.distance(a, b)
  local la, lb = #a, #b
  if la == 0 then
    return lb
  elseif lb == 0 then
    return la
  end
  local d = {}
  for i = 0, la do
    d[i] = { [0] = i }
  end
  for j = 0, lb do
    d[0][j] = j
  end
  for i = 1, la do
    for j = 1, lb do
      local cost = a:byte(i) == b:byte(j) and 0 or 1
      local v = math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
      if i > 1 and j > 1 and a:byte(i) == b:byte(j - 1) and a:byte(i - 1) == b:byte(j) then
        v = math.min(v, d[i - 2][j - 2] + 1)
      end
      d[i][j] = v
    end
  end
  return d[la][lb]
end

--- Closest candidate to `word`, if it's close enough to be a likely typo.
---@param word string
---@param candidates string[]
---@return string?
function M.suggest(word, candidates)
  local limit = #word <= 4 and 1 or 2
  local best, best_dist
  for _, candidate in ipairs(candidates) do
    local dist = M.distance(word, candidate)
    if dist <= limit and (not best_dist or dist < best_dist) then
      best, best_dist = candidate, dist
    end
  end
  return best
end

return M
