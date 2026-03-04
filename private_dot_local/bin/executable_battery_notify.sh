#!/usr/bin/env bash
while true; do
  cap=$(cat /sys/class/power_supply/BAT0/capacity)
  status=$(cat /sys/class/power_supply/BAT0/status)

  if [[ "$status" == "Discharging" && "$cap" -le 10 ]]; then
    notify-send -u critical -a "battery" "Battery low" "Battery at ${cap}%" -i battery-low
  fi

  sleep 300
done
