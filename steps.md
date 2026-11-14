# micro-which-key.nvim 進め方

| step | 内容 | 状態 |
|---|---|---|
| 0 | require できるモジュール | 済 |
| 1 | `candidates(keymaps, prefix)` 純粋関数 + テスト | 済 |
| 2 | float window で候補を表示する | 済 |
| 3 | getcharstr で1キーずつ読んで、prefix を伸ばすループ | 済 |
| 4 | 決まったキーを feedkeys で実行する（自分のマッピングで再帰しない） | 済 |
| 5 | 仕上げ: 表示の遅延、v:count / v:register、細かい挙動 | |

各 step の最後に、`nvim --clean -l tests/candidates_test.lua` が通ることを確認する。

---

## step 2: 表示

**作るもの**: `M.show(items)` と `M.hide()`

使う API
- `vim.api.nvim_create_buf(false, true)` — 一覧に出ない使い捨てのバッファ
- `vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)` — `items` を `"f  find"` のような行にして書く
- `vim.api.nvim_open_win(buf, false, opts)` — 2つ目の引数 `false` でフォーカスを移さない
  - `relative = 'editor'`, `row = vim.o.lines - 高さ - 2`, `col = 0`, `width = vim.o.columns`
  - `style = 'minimal'`, `border = 'rounded'`（`winborder` を設定済みなら省略できる）
- `vim.api.nvim_win_close(win, true)` — hide

気をつけること
- 2回 show したら窓が2枚にならないように、前の窓を閉じるか使い回す
- 日本語の desc で桁を揃えるなら、`#` ではなく `vim.fn.strdisplaywidth` で幅を測る
- `cmdheight=0` と ui2 を使っているので、row の位置は実際に開いて確かめる

完了条件
```vim
:lua local m = require('micro-which-key'); m.show(m.candidates(vim.api.nvim_get_keymap('n'), 'g'))
```
で float が出て、`:lua require('micro-which-key').hide()` で消える。

---

## step 3: キー入力のループ

**作るもの**: `M.start(prefix)`

```
prefix を持つ
loop:
  items = candidates(keymaps, prefix)
  show(items)
  redraw          ← しないと getcharstr の間 float が描かれない
  key = keytrans(getcharstr())
  <Esc>  → hide して終わり
  <BS>   → prefix を1キー戻す
  items に key がない → hide して終わり
  key がグループ → prefix = prefix .. key で続ける
  key が単体    → hide して step 4 の実行へ
```

使う API
- `vim.fn.getcharstr()` — `<C-c>` でエラーになるので `pcall` で包む
- `vim.fn.keytrans(char)` — lhs と同じ表記（`<C-G>`, `<lt>`）にそろえる。step 1 で確認済み
- `vim.cmd.redraw()`

気をつけること
- keymaps はループの最初に1回だけ取れば十分（`nvim_get_keymap(mode)` + `nvim_buf_get_keymap(0, mode)`）
- `<BS>` で1キー戻すとき、特殊キー `<C-G>` を1文字ずつ削らないこと。押したキーを配列に積んでおくと楽
- グループかどうかの判定は、`candidates()` の desc が `+` で始まるかを見るより、count などを返したほうが確実。返す形を変えたらテストも直す

完了条件: `:lua require('micro-which-key').start(' ')` で候補が出て、グループに入ると候補が変わり、`<Esc>` で消える（実行はまだしなくてよい）

---

## step 4: 実行

**作るもの**: 決まった lhs を実行する処理と、起動用のマッピング

```lua
local keys = vim.api.nvim_replace_termcodes(lhs, true, true, true)
vim.api.nvim_feedkeys(keys, 'mit', false)
```
- `m`: マッピングを効かせる（ユーザーのマッピングを動かしたいので必要）
- `i`: 先頭に入れる / `t`: ユーザーが打ったのと同じ扱い（undo やマクロ記録に正しく入る）
- `<C-G>` などは文字列のままでは送れないので `nvim_replace_termcodes` を通す

**再帰の問題**: 起動用に `nnoremap <Leader> <Cmd>lua require('micro-which-key').start(' ')<CR>` を置くと、`<Leader>f` を feedkeys した瞬間に先頭の `<Leader>` が自分のマッピングに当たり、また start が呼ばれる。

対策の候補
- 実行の直前に起動用マッピングを `vim.keymap.del` で外し、少し後で（`vim.schedule` など）付け直す。which-key は `Triggers.suspend` でこれをしている
- 付け直すタイミングが早すぎると、まだ処理されていないキーが自分に当たる。実際に動かして確かめる

完了条件: `<Leader>` → `-` で split される。`<Leader>` を押してから何も押さずに `<Esc>` で、何も起きない。

---

## step 5: 仕上げ（必要なものだけ）

- **表示の遅延**: すぐ float を出さず、`timeoutlen` を過ぎても次のキーが来ないときだけ出す。`vim.defer_fn` で show を予約し、その前にキーが来たら取り消す。getcharstr で待っている間にタイマーが動くかは実際に確かめる
- **自身も下もあるキー**（`gc` と `gcc`）: `gc` の後に何も押さなかったら `gc` 自身を実行する。timeout か `<CR>` で決める。今の `candidates()` は自身の desc を捨てているので、返す形を見直す
- **v:count / v:register**: `3<Leader>x` や `"a<Leader>y` を活かすなら、feedkeys の前に `vim.v.count`、`'"' .. vim.v.register` を付ける（which-key は state.lua:229-236）
- **除外**: `<Plug>` や `<SNR>` で始まる lhs は候補に出さない
- **他のモード**: visual（`x`）など。モードごとに keymaps を取り直す
