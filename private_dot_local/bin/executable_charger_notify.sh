#!/usr/bin/env bash

last_status="$(cat /sys/class/power_supply/BAT0/status)"

while true; do
  status="$(cat /sys/class/power_supply/BAT0/status)"

  if [[ "$status" != "$last_status" ]]; then
    case "$status" in
      Charging)
        notify-send -a "battery" "Power connected" "Charging started" -i battery-good-charging
        ;;
      Discharging)
        notify-send -a "battery" "Power disconnected" "Running on battery" -i battery-good
        ;;
      Full)
        notify-send -a "battery" "Battery full" "Charging complete" -i battery-full
        ;;
    esac

    last_status="$status"
  fi

  sleep 2
done
