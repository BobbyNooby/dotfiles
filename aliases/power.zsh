# lid: stay awake and keep working with the lid closed (for leaving agents running)
#   lid            toggle on/off
#   lid on|off     set explicitly
#   lid status     show current state
# While on: closing the lid does nothing, and no idle dim, lock, screen-off or sleep.
# How: a background user service (lid-inhibit) holds a systemd inhibitor — no sudo, and it
# outlives the terminal it was started from. hypridle respects the "idle" part.
# note: resets on reboot or logout — re-run lid on after restarting
# note: battery drains fast and heat builds with the lid closed — don't bag it for hours
lid() {
  local unit=lid-inhibit running=false want
  systemctl --user is-active --quiet $unit && running=true
  case "$1" in
    on)        want=on ;;
    off)       want=off ;;
    toggle|"") if $running; then want=off; else want=on; fi ;;
    status)    want=status ;;
    *) echo "usage: lid [on|off|toggle|status]"; return 1 ;;
  esac
  if [[ $want == on ]] && ! $running; then
    systemctl --user reset-failed $unit 2>/dev/null
    systemd-run --user --quiet --unit=$unit --description="Stay awake with the lid closed" \
      systemd-inhibit --what=handle-lid-switch:sleep:idle --who=lid --why="lid closed on purpose" \
      --mode=block sleep infinity
    sleep 0.3
    systemctl --user is-active --quiet $unit && running=true || { echo "lid: couldn't take the inhibitor — state unchanged"; return 1 }
  elif [[ $want == off ]] && $running; then
    systemctl --user stop $unit
    running=false
  fi
  if $running; then
    echo "lid ON — stays awake: lid closed, idle, nothing sleeps (resets on reboot)"
  else
    echo "lid OFF — sleeps normally (lid close, idle)"
  fi
}
alias clamshell='lid'
