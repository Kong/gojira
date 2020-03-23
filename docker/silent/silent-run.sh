#!/bin/bash

TIMER_PID=
BUILD_LOG=${BUILD_LOG:-$(mktemp /tmp/run.XXXXX)}
SILENT_WAIT=${SILENT_WAIT:-0.1}

function start_silent_run() {
  exec 5<&1
  exec 6<&2
  exec 1> $BUILD_LOG 2>&1

  trap on_err ERR

  init_timer "$1" &
  TIMER_PID=$!
}

function stop_silent_run() {
  kill_timer &> /dev/null
  trap - ERR
  exec 1<&5
  exec 2<&6
  exec 1>&1 2>&2
  echo ""
}

function get_phrase() {
  shuf -n 1 $BUILD_PREFIX/silent/.messages.txt
}

function init_timer() {
  local sp="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  local sc=0
  local addendum=$(get_phrase)

  SECONDS=0

  # set this to a higher wait if running on CI
  while true; do
    >&6 printf "\033[1K\r[${sp:$sc % 24:3} $1] $addendum "
    ((sc+=3))
    sleep $SILENT_WAIT

    [[ $(( $RANDOM % 30 )) == 0 ]] && addendum=$(get_phrase)
  done
}

function kill_timer() {
  # Tony Hawk trick. If you use SIGPIPE it will not have this ugly
  # Terminated message. We can do that because we know we are not handling
  # pipes on that PID
  kill -PIPE $TIMER_PID || true
}

function on_err() {
  stop_silent_run

  if [[ -n $BUILD_LOG ]]; then
    >&2 echo "Error during build:"
    >&2 echo "------------------------------------"
    >&2 tail -n 500 ${BUILD_LOG}
    >&2 echo "------------------------------------"
    >&2 echo "see full log ${BUILD_LOG}"
  fi

  exit 1
}
