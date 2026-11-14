-- 実行: nvim --clean -l tests/candidates_test.lua
local t = dofile('tests/helper.lua')
local eq = t.eq
local c = require('micro-which-key').candidates

eq('キーマップ1つ',
  { { key = 'f', desc = 'find', group = false } },
  c({ { lhs = ' f', desc = 'find' } }, ' '))

eq('同じキーの下にあるものはグループ +N にまとめる',
  { { key = 'f', desc = 'find', group = false }, { key = 'g', desc = '+2', group = true } },
  c({ { lhs = ' f', desc = 'find' }, { lhs = ' gs' }, { lhs = ' gc' } }, ' '))

eq('下に1つしかなくてもグループになる',
  { { key = 'g', desc = '+1', group = true } },
  c({ { lhs = ' gs', desc = 'status' } }, ' '))

eq('キーマップ自身とその下の両方がある → グループを優先し、自身は数えない',
  { { key = 'c', desc = '+1', group = true } },
  c({ { lhs = 'gc', desc = 'comment' }, { lhs = 'gcc', desc = 'line' } }, 'g'))

eq('孫も N に数える',
  { { key = 'g', desc = '+3', group = true } },
  c({ { lhs = ' gs' }, { lhs = ' gxa' }, { lhs = ' gxb' } }, ' '))

eq('prefix で始まらないものは除く',
  { { key = 'f', desc = 'find', group = false } },
  c({ { lhs = ' f', desc = 'find' }, { lhs = 'gd', desc = 'def' } }, ' '))

eq('prefix と同じ lhs は候補にしない',
  { { key = 's', desc = 'hs', group = false } },
  c({ { lhs = ' h', desc = 'h' }, { lhs = ' hs', desc = 'hs' } }, ' h'))

eq('特殊キーは <...> で1キーとして扱う',
  { { key = '<C-G>', desc = '+1', group = true }, { key = '<CR>', desc = 'enter', group = false }, { key = '<lt>', desc = 'lt', group = false } },
  c({ { lhs = ' <C-G>s' }, { lhs = ' <CR>', desc = 'enter' }, { lhs = ' <lt>', desc = 'lt' } }, ' '))

eq('prefix に特殊キーを含む',
  { { key = 's', desc = 'x', group = false }, { key = 't', desc = 'y', group = false } },
  c({ { lhs = ' <C-G>s', desc = 'x' }, { lhs = ' <C-G>t', desc = 'y' } }, ' <C-G>'))

eq('desc がなければ rhs、どちらもなければ空文字',
  { { key = 'q', desc = ':q<CR>', group = false }, { key = 'r', desc = '', group = false }, { key = 's', desc = 'save', group = false } },
  c({ { lhs = ' q', rhs = ':q<CR>' }, { lhs = ' r' }, { lhs = ' s', desc = 'save', rhs = ':w<CR>' } }, ' '))

eq('key の順に並ぶ（入力の順に関係なく）',
  { { key = 'a', desc = '', group = false }, { key = 'm', desc = '', group = false }, { key = 'z', desc = '', group = false } },
  c({ { lhs = ' z' }, { lhs = ' a' }, { lhs = ' m' } }, ' '))

eq('一致するものがなければ空の配列',
  {},
  c({ { lhs = ' f' } }, 'zz'))

do
  local keymaps = { { lhs = ' f', desc = 'find' }, { lhs = ' gs' } }
  local before = vim.deepcopy(keymaps)
  local first = c(keymaps, ' ')
  eq('入力を書き換えない', before, keymaps)
  eq('2回呼んでも同じ結果', first, c(keymaps, ' '))
end

t.finish()
