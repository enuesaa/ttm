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
  -history 	choose a directory from history
```

設定ファイル

```toml
[[paths]]
name = ".."
path = ".."

[[paths]]
name = "files"
path = "~"
command = """
echo "list files in ~"
ls -a
"""
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
