#!/bin/bash

window_id=$(xprop -root | grep '_NET_ACTIVE_WINDOW(WINDOW)' | awk '{print $5}')

window_title=$(xprop -id "$window_id" | grep '^WM_NAME' | cut -d '"' -f 2)

window_pid=$(xprop -id "$window_id" | grep '^_NET_WM_PID' | awk -F '= ' '{print $2}')

if [[ -n "$window_pid" ]]; then
    process_path=$(ps aux | grep "$window_pid" | grep -v grep | awk '{print $11}')

    process_name=$(basename "$process_path" | awk 'NR==1')
fi

echo "$window_title,$process_name"
