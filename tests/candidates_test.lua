-- 実行: nvim --clean -l tests/candidates_test.lua
vim.opt.rtp:prepend('.')
local c = require('micro-which-key').candidates

local failed = 0
local function eq(name, got, want)
  if vim.deep_equal(got, want) then
    print('ok   ' .. name)
  else
    failed = failed + 1
    print('FAIL ' .. name .. '\n  want: ' .. vim.inspect(want) .. '\n  got:  ' .. vim.inspect(got))
  end
end

eq('キーマップ1つ',
  c({ { lhs = ' f', desc = 'find' } }, ' '),
  { { key = 'f', desc = 'find' } })

eq('同じキーの下にあるものはグループ +N にまとめる',
  c({ { lhs = ' f', desc = 'find' }, { lhs = ' gs' }, { lhs = ' gc' } }, ' '),
  { { key = 'f', desc = 'find' }, { key = 'g', desc = '+2' } })

eq('下に1つしかなくてもグループになる',
  c({ { lhs = ' gs', desc = 'status' } }, ' '),
  { { key = 'g', desc = '+1' } })

eq('キーマップ自身とその下の両方がある → グループを優先し、自身は数えない',
  c({ { lhs = 'gc', desc = 'comment' }, { lhs = 'gcc', desc = 'line' } }, 'g'),
  { { key = 'c', desc = '+1' } })

eq('孫も N に数える',
  c({ { lhs = ' gs' }, { lhs = ' gxa' }, { lhs = ' gxb' } }, ' '),
  { { key = 'g', desc = '+3' } })

eq('prefix で始まらないものは除く',
  c({ { lhs = ' f', desc = 'find' }, { lhs = 'gd', desc = 'def' } }, ' '),
  { { key = 'f', desc = 'find' } })

eq('prefix と同じ lhs は候補にしない',
  c({ { lhs = ' h', desc = 'h' }, { lhs = ' hs', desc = 'hs' } }, ' h'),
  { { key = 's', desc = 'hs' } })

eq('特殊キーは <...> で1キーとして扱う',
  c({ { lhs = ' <C-G>s' }, { lhs = ' <CR>', desc = 'enter' }, { lhs = ' <lt>', desc = 'lt' } }, ' '),
  { { key = '<C-G>', desc = '+1' }, { key = '<CR>', desc = 'enter' }, { key = '<lt>', desc = 'lt' } })

eq('prefix に特殊キーを含む',
  c({ { lhs = ' <C-G>s', desc = 'x' }, { lhs = ' <C-G>t', desc = 'y' } }, ' <C-G>'),
  { { key = 's', desc = 'x' }, { key = 't', desc = 'y' } })

eq('desc がなければ rhs、どちらもなければ空文字',
  c({ { lhs = ' q', rhs = ':q<CR>' }, { lhs = ' r' }, { lhs = ' s', desc = 'save', rhs = ':w<CR>' } }, ' '),
  { { key = 'q', desc = ':q<CR>' }, { key = 'r', desc = '' }, { key = 's', desc = 'save' } })

eq('key の順に並ぶ（入力の順に関係なく）',
  c({ { lhs = ' z' }, { lhs = ' a' }, { lhs = ' m' } }, ' '),
  { { key = 'a', desc = '' }, { key = 'm', desc = '' }, { key = 'z', desc = '' } })

eq('一致するものがなければ空の配列',
  c({ { lhs = ' f' } }, 'zz'),
  {})

do
  local keymaps = { { lhs = ' f', desc = 'find' }, { lhs = ' gs' } }
  local before = vim.deepcopy(keymaps)
  local first = c(keymaps, ' ')
  eq('入力を書き換えない', keymaps, before)
  eq('2回呼んでも同じ結果', c(keymaps, ' '), first)
end

if failed > 0 then
  print(failed .. ' failed')
  os.exit(1)
end
