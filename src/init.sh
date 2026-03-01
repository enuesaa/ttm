if [[ "$TTM" == "true" ]]; then
  if [[ "$TTM_NESTED" =~ ^\*+$ ]]; then
    echo 'PS1="%F{yellow}ttm${TTM_NESTED}%f $PS1"'
  fi
fi

# fish
# function fish_prompt
#   if test "$TTM" = "true"
#     set_color yellow
#     echo -n "[ttm] "
#     set_color normal
#   end
#   echo -n (prompt_pwd) "> "
# end
