eval `luarocks path 2> /dev/null`
LUA_PATH="$KONG_PATH/?.lua;$KONG_PATH/?/init.lua;$KONG_PLUGIN_PATH/?.lua;$KONG_PLUGIN_PATH/?/init.lua;$LUA_PATH"
PATH="$PATH:$KONG_PATH/bin"

function make_prompt {
  local res=$?
  local usr path

  [ "$res" = 0 ] && hint="\[\033[1;34m\]" || hint="\[\033[1;91m\]"
  [ "$PWD" = "$HOME" ] && path="~" || path=$PWD
  [ "$USER" = "root" ] && usr="#" || usr="$"

  PS1="\[\e[00m\]$hint[$GOJIRA_PREFIX:\[\033[1;92m\]$path$hint]$usr\[\033[00m\] "
}

USER=`whoami`
PROMPT_COMMAND=make_prompt
