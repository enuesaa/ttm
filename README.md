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

ttm でセッションをスタート

```bash
# start session
ttm

# exit
exit
```

## Development
```bash
zig build run
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
