# lid: keep the laptop awake with the lid closed (no external display needed)
#   lid            toggle on/off
#   lid on|off     set explicitly
#   lid status     show current state
# How: holds a systemd "lid switch" inhibitor in the background (no sudo needed).
# note: resets on reboot or logout — re-run lid on after restarting
# note: battery drains fast and heat builds with the lid closed — don't bag it for hours
lid() {
  local pidfile="${XDG_RUNTIME_DIR:-/tmp}/lid-inhibit.pid"
  local running=false want
  [[ -f "$pidfile" ]] && kill -0 "$(<"$pidfile")" 2>/dev/null && running=true
  case "$1" in
    on)        want=on ;;
    off)       want=off ;;
    toggle|"") if $running; then want=off; else want=on; fi ;;
    status)    want=status ;;
    *) echo "usage: lid [on|off|toggle|status]"; return 1 ;;
  esac
  if [[ $want == on ]] && ! $running; then
    systemd-inhibit --what=handle-lid-switch:sleep --who=lid --why="lid closed on purpose" \
      --mode=block sleep infinity >/dev/null 2>&1 &
    echo $! > "$pidfile"
    disown
    sleep 0.3
    kill -0 "$(<"$pidfile")" 2>/dev/null && running=true || { echo "lid: couldn't take the inhibitor — state unchanged"; return 1 }
  elif [[ $want == off ]] && $running; then
    kill "$(<"$pidfile")" 2>/dev/null
    rm -f "$pidfile"
    running=false
  fi
  if $running; then
    echo "sleep DISABLED — laptop stays awake with lid closed (resets on reboot)"
  else
    echo "sleep ENABLED — laptop sleeps normally when lid closes"
  fi
}
alias clamshell='lid'
