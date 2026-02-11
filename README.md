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
- 履歴を取りたい

```zsh
preexec() {
  local fmt_date="$(date +'%Y-%m-%d.%H:%M:%S')"
  echo "${fmt_date} \"${PWD}\" $1" >> ~/.config/zsh-full-$(date +'%Y-%m-%d').log
}
```

- ファイル移動を主軸に考えなおそうかな
- tmp dir を作っても仕方ない気がしてきた
