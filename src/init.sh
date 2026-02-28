if [[ "$TTM" == "true" ]]; then
  echo 'PS1="%F{yellow}[ttm]%f $PS1"'
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
