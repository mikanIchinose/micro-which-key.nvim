--- テスト用の小さな道具箱
---
--- 使い方（テストファイルの中）:
---
---   local t = dofile('tests/helper.lua')
---   local eq = t.eq
---
---   eq('1 + 1 は 2', 2, 1 + 1)
---   eq('配列も中身で比べる', { 'a', 'b' }, { 'a', 'b' })
---
---   t.finish()  -- 必ず最後に呼ぶ
---
--- 実行（リポジトリ直下で）:
---
---   nvim --clean -l tests/xxx_test.lua
---
--- 前提:
--- - リポジトリ直下で実行すること。dofile も rtp も '.' からの相対パスで探すため
--- - require ではなく dofile で読む。require が探すのは lua/ の下だけで、tests/ は探さない
--- - 読み込むと rtp に '.' が足され、require('micro-which-key') が使えるようになる
---
--- 出力:
---   ok   <name>                成功
---   FAIL <name>                失敗。続けて expected（期待値）と actual（実際の値）を表示
---     expected: ...
---     actual:   ...
---   <N> failed                 finish() で、失敗が1つ以上あったときだけ表示

vim.opt.rtp:prepend('.')

local M = {}

--- これまでに失敗した eq の数。finish() が見る
local failed = 0

--- actual が expected と同じか確かめ、結果を1行表示する
---
---@param name string 何を確かめているか。ok / FAIL の後ろに表示される
---@param expected any 期待する値
---@param actual any 実際の値（テストしたい関数の戻り値など）
function M.eq(name, expected, actual)
  if vim.deep_equal(expected, actual) then
    print('ok   ' .. name)
  else
    failed = failed + 1
    print('FAIL ' .. name .. '\n  expected: ' .. vim.inspect(expected) .. '\n  actual:   ' .. vim.inspect(actual))
  end
end

--- テストファイルの最後に1回呼ぶ
---
--- 失敗が1つでもあれば件数を表示して、終了コード1で nvim を終わらせる。
function M.finish()
  if failed > 0 then
    print(failed .. ' failed')
    os.exit(1)
  end
end

return M
