#!/usr/bin/env bash

if pkill -INT -x wf-recorder; then
  notify-send -u low -i "camera" "Recording finished"
  exit 0
fi

choice="$(printf "GIF\nMP4\nMP4+Audio\n" | hyprlauncher --dmenu)" || exit 0 [[ -n "${choice:-}" ]] || exit 0

sleep 0.2

case "$choice" in
"GIF")
wf-recorder -g "$(slurp)" -c gif -f "$HOME/Videos/screenrecord-$(date +%Y-%m-%dT%H-%M-%S).gif"
;;
"MP4")
wf-recorder -g "$(slurp)" -f "$HOME/Videos/screenrecord-$(date +%Y-%m-%dT%H-%M-%S).mp4"
;;
"MP4+Audio")
wf-recorder -g "$(slurp)" -a -f "$HOME/Videos/screenrecord-$(date +%Y-%m-%dT%H-%M-%S).mp4"
;;
*)
exit 0
;;
esac
