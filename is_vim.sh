#!/usr/bin/env bash

# Get PID of current tmux pane
pane_pid=$(tmux display -p "#{pane_pid}")

# Exit early if no PID is retrieved
[ -z "$pane_pid" ] && exit 1 

# Retrieve all descendant processes of the tmux pane's shell by iterating through the process tree.
# This includes child processes and their descendants recursively.
# excludes "stopped" processes as they are not considered active.
descendants=$(ps -eo pid=,ppid=,stat= | awk -v pid="$pane_pid" '{
    if ($3 !~ /^T/) {
        pid_array[$1]=$2
    }
} END {
    for (p in pid_array) {
        current_pid = p
        while (current_pid != "" && current_pid != "0") {
            if (current_pid == pid) {
                print p
                break
            }
            current_pid = pid_array[current_pid]
        }
    }
}')

# Check if there are any descendant processes.
if [ -n "$descendants" ]; then
    # Convert the list of descendant PIDs into a comma-separated string.
    descendant_pids=$(echo "$descendants" | tr '\n' ',' | sed 's/,$//')

    # Check if any of the descendant processes match a Vim-related command.
    ps -o args= -p "$descendant_pids" | grep -iqE "(^|/)([gn]?vim?x?)(diff)?"

    # Exit with success if a Vim-related command is found.
    if [ $? -eq 0 ]; then
        exit 0
    fi
fi

# Exit with failure if no Vim-related process is detected.
exit 1
