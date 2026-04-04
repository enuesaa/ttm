# ttm
A CLI tool to move another directory temporarily

## Commands
```bash
➜ zig build run -- --help
ttm
A CLI tool to move another directory temporarily.

Usage:
  ttm <to>

Flags:
  --help	show help
  --version	show version
  --init	print hook script for zsh
  -l, --list	list directories to move
  --set	add or update directory configuration
```

指定のディレクトリでセッションを開始する

```bash
ttm    # start session. move to default dir. and exit.
ttm .  # move to current dir
ttm .. # move to parent dir
```

設定ファイル

```toml
[[paths]]
name = "default"
path = "~"

[[paths]]
name = ".."
path = ".."
```

## feature plans
- completion
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
```

- history
- env vars
- prompt
