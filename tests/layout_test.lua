-- 実行: nvim --clean -l tests/layout_test.lua
local t = dofile('tests/helper.lua')
local eq = t.eq
local layout = require('micro-which-key').layout

-- セルは ' key desc' を一番広いものに合わせ、後ろに2桁あける
-- ' a x' は4桁 → セル幅は6
local abc = { { key = 'a', desc = 'x' }, { key = 'b', desc = 'y' }, { key = 'c', desc = 'z' } }

eq('幅が1セル分しかなければ1列',
  { ' a x  ', ' b y  ', ' c z  ' },
  layout(abc, 6))

eq('2列なら上から下へ並べ、あふれた分を次の列へ',
  { ' a x   c z  ', ' b y  ' },
  layout(abc, 12))

eq('全部入る幅なら1行',
  { ' a x   b y   c z  ' },
  layout(abc, 18))

eq('幅が余ってもセルは広げない',
  { ' a x   b y   c z  ' },
  layout(abc, 80))

eq('セルより狭い画面でも1列は出す',
  { ' a x  ', ' b y  ', ' c z  ' },
  layout(abc, 3))

eq('日本語は表示幅で揃える',
  { ' a 日本   b x     ' },
  layout({ { key = 'a', desc = '日本' }, { key = 'b', desc = 'x' } }, 18))

eq('長さの違う key でも列は揃う',
  { ' <C-G> x   a y      ' },
  layout({ { key = '<C-G>', desc = 'x' }, { key = 'a', desc = 'y' } }, 22))

do
  local items = {}
  for i = 1, 10 do
    table.insert(items, { key = string.char(96 + i), desc = 'd' })
  end
  -- ' a d' は4桁、セル幅6 → 幅18 で3列、10件なら4行
  local lines = layout(items, 18)
  eq('10件を3列に並べると4行', 4, #lines)
  eq('最後の行は残りの1件だけ', ' d d   h d  ', lines[4])
  local too_wide = vim.tbl_filter(function(l) return vim.fn.strdisplaywidth(l) > 18 end, lines)
  eq('どの行も幅を超えない', {}, too_wide)
end

do
  local before = vim.deepcopy(abc)
  layout(abc, 12)
  eq('入力を書き換えない', before, abc)
end

t.finish()
