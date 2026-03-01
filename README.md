# ttm
A CLI tool to move another directory temporarily

## Commands
```bash
➜ ttm --help
ttm
A CLI tool to move another directory temporarily.

Usage:
  ttm <to>

Flags:
  --help	show help
  --version	show version
  --init	print hook script for zsh
```

### ttm
ttm でセッションをスタート。exit したら即座にアーカイブ

```bash
# start session
ttm

# exit
exit
```

### ttm ls
過去のセッションをリスト

```bash
$ ttm ls
[q] Quit, [Enter] Start shell

 > 202510251849-ax52t │
   202510251857-iz3ws │
   202510191513-o7roe │
```

- 今の時点ではすべてのユースケースを考慮しない
- セッションが終わってもディレクトリを圧縮しない

### ttm pin
```bash
ttm pin last
```

## Development
```bash
zig build run
zig build test
```

## Feature Plans

ファイル移動を主軸に考えなおす

```bash
ttm    # start session. move to default dir. and exit.
ttm @  # move to ~/tmp dir
ttm .  # move to current dir
ttm .. # move to parent dir
```

設定ファイル

```json
{
  "paths": {
    "default": {
      // `ttm` でここに移動するイメージ
      "path": "$HOME/repos"
    },
    "@": {
      // `ttm @` でここに移動するイメージ
      "path": "$HOME/tmp"
    }
  }
}
```

こんな感じでshellのpromptを変えられる
```
PROMPT="%F{yellow}[ttm]%f %~ $ "
PS1="[ttm] $PS1"
```

completion
```bash
➜ _foo_completion() {
  local -a subcmds
  subcmds=(
    start
    stop
    restart
    status
  )

  compadd -- $subcmds
}
~/tmp
➜ compdef _foo_completion foo
~/tmp
➜ foo restart
```
