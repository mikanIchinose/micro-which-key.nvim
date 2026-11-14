# micro-which-key.nvim 進め方

| step | 内容 | 状態 |
|---|---|---|
| 0 | require できるモジュール | 済 |
| 1 | `candidates(keymaps, prefix)` 純粋関数 + テスト | 済 |
| 2 | float window で候補を表示する | 済 |
| 3 | getcharstr で1キーずつ読んで、prefix を伸ばすループ | 済 |
| 4 | 決まったキーを feedkeys で実行する（自分のマッピングで再帰しない） | 済 |
| 5 | 起動キーの自動登録（which-key と同じ方式）と仕上げ | 進行中 |

各 step の最後に、`tests/` の下のテストがすべて通ることを確認する。

```sh
for f in tests/*_test.lua; do nvim --clean -l $f || echo "FAIL: $f"; done
```

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

→ **実際には起きなかった**（`<nowait>` の有無どちらでも確認済み）。feedkeys は `<Space>-` を一度にまとめて送る。Neovim は、手元に来ているキーで当てはまるマッピングのうち最も長いもの（`<Space>-`）を選ぶので、起動用の `<Space>` には当たらない。which-key の `Triggers.suspend` のような「外して付け直す」仕組みは不要だった。

起動用マッピングには `nowait = true` を付ける。付けないと、`<Space>` を押した後に `timeoutlen`（既定は1秒）だけ次のキーを待ち、その間 float が出ない。

完了条件: `<Leader>` → `-` で split される。`<Leader>` を押してから何も押さずに `<Esc>` で、何も起きない。

---

## step 5: 起動キーの自動登録と仕上げ

起動用マッピングを自分で書かずに済むよう、which-key と同じ方式で起動キーを自動で決めて登録する。

### which-key のやり方（ソースで確認済み）

- 起動用マッピングは which-key 自身が `vim.keymap.set(mode, keys, …, { nowait = true, desc = 'which-key-trigger' })` で作る（`triggers.lua:43`）
- どのキーを起動キーにするかは `buf.lua:22` の `is_safe` で決める
  - 下にマッピングがあり、自身にはマッピングがない、いちばん上のキー
  - 1文字の英字は `g` `z` `Z` 以外は選ばない（`ds` があるからと `d` を乗っ取ると `dd` が壊れる）
- `BufEnter`・`LspAttach` などのたびに選び直す（後から足されるマッピングに追いつくため）

### 5-1: 候補にないキーをそのまま Neovim に流す

**なぜ先にやるか**: これがないと `g` や `[` や `<C-W>` を起動キーにできない。`gg` や `<C-W>v` は Neovim に最初からある操作でマッピングではないので、候補に出ない。今の `start` は候補にないキーを捨てて閉じるので、`g` を起動キーにすると `gg` が効かなくなる（試して確認済み: 50行目から `gg` しても50行目のまま）。

**作るもの**: `start` の「候補にないものを入力したら終了」の分岐で、捨てずに送る

```lua
local lhs = prefix .. table.concat(keys) .. key
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, true, true), 'nit', false)
```
- `n`: マッピングを効かせない。候補にない＝その先にマッピングはないので、マッピングを効かせる必要はない。しかも `m` だと、先頭の `g` がまた起動用マッピングに当たって start が呼ばれる（step 4 で起きなかった再帰が、ここでは起きる）

完了条件: `g` を起動キーにして（`vim.keymap.set('n', 'g', function() require('micro-which-key').start('g') end, { nowait = true })`）、`gg` で先頭へ、`gx` などのマッピングも動く。

### 5-2: `setup()` で起動キーを自動で登録する

**作るもの**: `M.setup()`

```
keymaps = getKeymaps('n')
items = candidates(keymaps, '')         ← いちばん上のキーの一覧。group が true のものが候補
各 item について、起動キーにしてよいか判定:
  - <Plug> は除く（人が押すキーではない）
  - 1文字の英字は g z Z 以外は除く
  - 自身にもマッピングがあるものは除く
OK なら vim.keymap.set('n', key, function() M.start(key) end, { nowait = true, desc = 'micro-which-key' })
```

気をつけること
- `setup()` が作った起動用マッピングも `getKeymaps` に入ってくる。自分の desc（`micro-which-key`）が付いたものは `getKeymaps` で除く。除かないと `<Space>` が「自身にもマッピングがある」扱いになり、2回目の判定で外れる
- 「自身にもマッピングがあるか」は今の `candidates` では分からない（desc が `+N` で上書きされる）。`candidates` の返す形を変えるか、`setup` の中で keymaps を直接見る
- 普段の設定で今の判定をすると、`<Space>` `g` `[` `]` `<C-W>` が起動キーになる見込み（`<Plug>` は除外）
- 自分の init.lua に置いた起動用の `<Space>` マッピングは消す

完了条件: init.lua に `require('micro-which-key').setup()` だけを書いて、`<Space>` と `g` で候補が出る。`gg`・`<C-W>v`・`]]` が今までどおり動く。

### 5-3: 選び直し

`setup()` の時点ではまだないマッピングがある（遅れて読み込まれるプラグイン、LSP がバッファごとに足すマッピング）。`BufEnter` と `LspAttach` で起動キーを選び直す（`vim.api.nvim_create_autocmd`）。バッファごとのマッピングに対しては、起動用マッピングもそのバッファに付ける（`buffer = 番号`）。

完了条件: LSP が足した `g` 系のマッピングが、`g` の候補に出る。

### 5-4: 仕上げ（必要なものだけ）

- **表示の遅延**: すぐ float を出さず、`timeoutlen` を過ぎても次のキーが来ないときだけ出す。`vim.defer_fn` で show を予約し、その前にキーが来たら取り消す。getcharstr で待っている間にタイマーが動くかは実際に確かめる
- **自身も下もあるキー**（`gc` と `gcc`）: `gc` の後に何も押さなかったら `gc` 自身を実行する。timeout か `<CR>` で決める。今の `candidates()` は自身の desc を捨てているので、返す形を見直す（5-2 の「自身にもマッピングがあるか」と同じ情報）
- **v:count / v:register**: `3<Leader>x` や `"a<Leader>y` を活かすなら、feedkeys の前に `vim.v.count`、`'"' .. vim.v.register` を付ける（which-key は state.lua:229-236）
- **他のモード**: visual（`x`）など。モードごとに keymaps を取り直す
