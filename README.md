# ttm
A CLI tool to move another directory temporarily

## Commands
```bash
➜ ttm -help
ttm
A CLI tool to move another directory temporarily.

Usage:
  ttm <to>

Flags:
  -help    	show help
  -version  show version
  -edit    	edit ttm config file
  -l, -list	list directories to move
  -last    	move to the last opened directory
```

設定ファイル

```toml
[[paths]]
name = "default"
path = "."

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
