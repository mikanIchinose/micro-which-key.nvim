local M = {}

function M.candidates(keymaps, prefix)
  local by_key = {}
  for _, m in ipairs(keymaps) do
    if  #m.lhs > #prefix and vim.startswith(m.lhs, prefix) then
      local rest = m.lhs:sub(#prefix + 1)
      local key = rest:match('^<[^>]+>') or rest:sub(1, 1)
      local is_self = rest:sub(#key + 1) == ''
      by_key[key] = by_key[key] or { count = 0 }
      if is_self then
        by_key[key].desc = m.desc or m.rhs or ''
      else
        by_key[key].count = by_key[key].count + 1
      end
    end
  end
  local result = {}
  for k, c in pairs(by_key) do
    local desc = c.count > 0 and ('+%d'):format(c.count) or c.desc
    table.insert(result, {key=k,desc=desc})
  end
  table.sort(result, function(a, b) return a.key < b.key end)
  return result
end

return M

