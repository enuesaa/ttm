# ttm
A CLI tool to manage tmp dirs for throwaway work

## Commands
```bash
➜ ttm --help
ttm
Version: 0.0.4

USAGE:
  ttm [OPTIONS]

A CLI tool to manage tmp dirs for throwaway work

COMMANDS:
  ls      list tmp dirs
  pin     rename and keep tmp dir
  rm      remove tmp dir
  prune   remove archived tmp dirs

OPTIONS:
  -h, --help            Show this help output.
      --color <VALUE>   When to use colors (*auto*, never, always).
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

```yaml
paths:
  default:
    path: $HOME/repos # ttm コマンドでここに移動するイメージ
  @:
    path: $HOME/tmp # ttm t コマンドでここに移動するイメージ
    archive: true # zip に固めて七日間保存するイメージ
    envs:
      AA: bb
  tmp:
    path: $HOME/tmp
  .:
    path: $PWD
  ..:
    path: ../$PWD

archiveDays: 7
```

```json
{
  "paths": {
    "default": {
      "path": "$HOME/repos"
    },
    "@": {
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

samples
```bash
ttm() {
  case "$1" in
    "" )
      cd ~ || return
      ;;
    "@" )
      cd ~/tmp || return
      ;;
    "." )
      cd . || return
      ;;
    ".." )
      # 親ディレクトリへ
      cd .. || return
      ;;
    * )
      echo "ttm: unknown argument '$1'" >&2
      return 1
      ;;
  esac
}
```
