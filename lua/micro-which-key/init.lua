local M = {}

local win

function M.hide()
  -- windowがまだ開いていれば閉じる
  -- 外部要因で閉じられている可能性があるのでvim.api.nvim_win_is_validでチェックする
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  win = nil
end

-- itemsをwidth桁に収まるように複数行に並べた列の配列を返す
function M.layout(items, width)
  -- 各項目を表示用の文字にして、一番広い幅を覚える
  local cells = {}
  local cell_w = 0
  for _, item in ipairs(items) do
    local s = (' %s %s'):format(item.key, item.desc)
    table.insert(cells, s)
    cell_w = math.max(cell_w, vim.fn.strdisplaywidth(s))
  end
  cell_w = cell_w + 2

  -- 列の数と行の数
  local ncols = math.max(1, math.floor(width / cell_w))
  local nrows = math.ceil(#cells / ncols)

  local lines = {}
  for r = 1, nrows do
    local row = {}
    for c = 1, ncols do
      -- r行、c列目の文字
      local s = cells[(c - 1) * nrows + r]
      if s then
        local how_many_spaces = cell_w - vim.fn.strdisplaywidth(s)
        s = s .. string.rep(' ', how_many_spaces)
        table.insert(row, s)
      end
    end
    table.insert(lines, table.concat(row))
  end
  return lines
end

function M.show(items)
  M.hide()
  if #items == 0 then return end

  local lines = M.layout(items, vim.o.columns - 2)
  local height = #lines

  -- バッファを作る
  local buf = vim.api.nvim_create_buf(false, true)
  -- バッファに文字を書く
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  -- ウィンドウを開く
  win = vim.api.nvim_open_win(buf, false, {
    relative = 'editor',
    row = vim.o.lines - height - 2,
    col = 0,
    width = vim.o.columns,
    height = height,
    style = 'minimal',
    border = 'rounded',
  })
end

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
    local group = c.count > 0
    table.insert(result, {key=k,desc=desc,group=group})
  end
  table.sort(result, function(a, b) return a.key < b.key end)
  return result
end

function M.getKeymaps(mode)
  local keymaps = {}
  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
    table.insert(keymaps, { lhs = vim.fn.keytrans(m.lhsraw), desc = m.desc, rhs = m.rhs })
  end
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
    table.insert(keymaps, { lhs = vim.fn.keytrans(m.lhsraw), desc = m.desc, rhs = m.rhs })
  end
  return keymaps
end

-- which-keyの表示をループする
function M.start(prefix)
  -- normal modeのキーマップ全部詰め込む
  local keymaps = M.getKeymaps('n')

  local keys = {} -- ユーザーが入力したキー
  while true do
    local candidates = M.candidates(keymaps, prefix .. table.concat(keys))
    M.show(candidates)
    vim.cmd.redraw()

    -- 次の入力を待つ
    local ok, ch = pcall(vim.fn.getcharstr)
    if not ok then
      M.hide()
      return
    end

    local key = vim.fn.keytrans(ch)
    if key == '<Esc>' then
      -- <Esc> で脱出
      M.hide()
      return
    elseif key == '<BS>' then
      if #keys == 0 then
        M.hide()
        return
      end
      -- 前の入力に戻す
      table.remove(keys)
    else
      local nextItem = vim.iter(candidates):find(function(it) return it.key == key end)
      -- 候補にないものを入力したら終了
      if not nextItem then
        M.hide()
        return
      elseif nextItem.group then
        table.insert(keys, nextItem.key)
      else
        -- コマンドが入力完了しているので終了
        M.hide()
        return
      end
    end
  end
end

return M

