#!/usr/bin/env bash
set -euo pipefail

abs() {
    local value=$1
    if (( value < 0 )); then
        echo $(( -value ))
    else
        echo "$value"
    fi
}

workspace_id=$(hyprctl activeworkspace -j | jq -r '.id')
clients_json=$(hyprctl clients -j)
active_window_address=$(hyprctl activewindow -j | jq -r '.address // empty')

declare -a tiled_addresses=()
declare -A center_x=()
declare -A center_y=()

while IFS=$'\t' read -r address x y; do
    tiled_addresses+=("$address")
    center_x["$address"]=$x
    center_y["$address"]=$y
done < <(
    jq -r --argjson workspace_id "$workspace_id" '
        .[]
        | select(.workspace.id == $workspace_id and (.floating | not))
        | [
            .address,
            ((.at[0] + (.size[0] / 2)) | floor),
            ((.at[1] + (.size[1] / 2)) | floor)
          ]
        | @tsv
    ' <<<"$clients_json"
)

if (( ${#tiled_addresses[@]} < 2 )); then
    exit 0
fi

anchor_address=${tiled_addresses[0]}
for address in "${tiled_addresses[@]}"; do
    if [[ $address == "$active_window_address" ]]; then
        anchor_address=$address
        break
    fi
done

hyprctl --batch "dispatch focuswindow address:$anchor_address; dispatch togglegroup;"

declare -a sorted_windows=()
while IFS=$'\t' read -r _distance address; do
    sorted_windows+=("$address")
done < <(
    for address in "${tiled_addresses[@]}"; do
        if [[ $address == "$anchor_address" ]]; then
            continue
        fi

        dx=$(( center_x["$address"] - center_x["$anchor_address"] ))
        dy=$(( center_y["$address"] - center_y["$anchor_address"] ))
        distance=$(( $(abs "$dx") + $(abs "$dy") ))

        printf '%s\t%s\n' "$distance" "$address"
    done | sort -n
)

for address in "${sorted_windows[@]}"; do
    dx=$(( center_x["$anchor_address"] - center_x["$address"] ))
    dy=$(( center_y["$anchor_address"] - center_y["$address"] ))

    if (( $(abs "$dx") >= $(abs "$dy") )); then
        if (( dx < 0 )); then
            direction=l
        else
            direction=r
        fi
    else
        if (( dy < 0 )); then
            direction=u
        else
            direction=d
        fi
    fi

    hyprctl --batch "dispatch focuswindow address:$address; dispatch moveintogroup $direction;"
done

if [[ -n $active_window_address ]]; then
    hyprctl dispatch focuswindow "address:$active_window_address"
fi
