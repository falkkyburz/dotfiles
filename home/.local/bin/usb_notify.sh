#!/bin/bash

# Verify that sound file exists
if [ ! -f $1 ]; then
    exit 0
fi

# 2. Iterate through all active user sessions in /run/user
for user_dir in /run/user/*; do
    uid=$(basename "$user_dir")
    # Verify that user has a Pulse/PipeWire socket active
    if [ -e "$user_dir/pulse/native" ]; then
        # Get the username associated with the UID
        target_user=$(id -nu "$uid")
        # 3. Play the sound as that user
        sudo -u "$target_user" XDG_RUNTIME_DIR="/run/user/$uid" paplay "$1" &
    fi
done
