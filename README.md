# Vim Detection in Tmux Panes

This repository contains a Bash script that detects whether a **Vim-related process** (e.g., `vim`, `nvim`, or `vimdiff`) is running in the **current tmux pane**. The script resolves several challenges with identifying nested Vim processes and provides a reliable way to determine whether to send key inputs to tmux or the active Vim instance.

## **Purpose**

When using **tmux** with tools like [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator), it's common to configure key bindings (e.g., `Ctrl-h`, `Ctrl-j`, `Ctrl-k`, `Ctrl-l`) to either:

1. **Switch tmux panes** when not in Vim.
2. **Send key inputs** to Vim for navigation when in a Vim pane.

This script enables you to conditionally send keys to either tmux or Vim, ensuring a seamless user experience.

## **Key Challenges with Previous Approaches**

1. **Issues with Nested Processes**:
   - Previous attempts relied on directly querying the process running in the pane's TTY using commands like:

     ```bash
     is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
       | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'"
     ```

   - This approach failed to correctly identify **nested Vim processes**, as it only checked the immediate process attached to the TTY. Vim processes launched indirectly (e.g., through subshells or scripts) were missed.

2. **Process Tree Complexity**:
   - Tmux panes often have multiple layers of processes (e.g., shell, background tasks, Vim).
   - A reliable solution needed to traverse the **entire process tree** to identify Vim-related commands.

## **How It Works**

The script works by:

1. **Retrieving the Pane PID**:
   - It identifies the PID of the tmux pane's shell using:

     ```bash
     tmux display -p "#{pane_pid}"
     ```

2. **Finding Descendant Processes**:
   - It traverses the process tree to identify all descendant processes of the pane's shell, including nested Vim processes.

3. **Checking for Vim Processes**:
   - It searches the descendant processes for Vim-related commands (`vim`, `nvim`, `vimdiff`, etc.) using:

     ```bash
     ps -o args= -p "$descendant_pids" | grep -iqE "(^|/)([gn]?vim?x?)(diff)?"
     ```

4. **Exit Status**:
   - **Exit 0 (True):** A Vim-related process is detected.
   - **Exit 1 (False):** No Vim-related process is found.

## **Script**

Here’s the script for reference:

```bash
#!/usr/bin/env bash

# Get PID of current tmux pane
pane_pid=$(tmux display -p "#{pane_pid}")

# Exit early if no PID is retrieved
[ -z "$pane_pid" ] && exit 1 

# Retrieve all descendant processes of the tmux pane's shell by iterating through the process tree.
# This includes child processes and their descendants recursively.
descendants=$(ps -eo pid=,ppid= | awk -v pid="$pane_pid" '{
    pid_array[$1]=$2
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
```

## **How to Use**

1. **Clone the Repository**

   ```bash
   git clone <repository-url>
   cd <repository-folder>
   ```

2. **Make the Script Executable**

   ```bash
   chmod +x is_vim.sh
   ```

3. **Integrate with Tmux**
   Update your `~/.tmux.conf` to use the script for conditional key bindings:

   ```tmux
   # Example key bindings
   bind-key -n 'C-h' if-shell "/path/to/is_vim.sh" 'send-keys C-h' 'select-pane -L'
   bind-key -n 'C-j' if-shell "/path/to/is_vim.sh" 'send-keys C-j' 'select-pane -D'
   bind-key -n 'C-k' if-shell "/path/to/is_vim.sh" 'send-keys C-k' 'select-pane -U'
   bind-key -n 'C-l' if-shell "/path/to/is_vim.sh" 'send-keys C-l' 'select-pane -R'
   ```

4. **Reload Tmux Configuration**

   ```bash
   tmux source-file ~/.tmux.conf
   ```

5. **Test**
   - Open Vim or Neovim in a tmux pane and use your key bindings.
   - The script should correctly identify whether to send keys to tmux or Vim.

## **Limitations**

- **Performance:** Traversing the process tree for every key press can introduce slight latency in complex setups.
- **Process Matching:** Relies on process names to detect Vim; custom setups with non-standard names may require modifications to the `grep` pattern.

## **License**

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
