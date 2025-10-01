# pomo-cli: A Pomodoro timer function for your shell
pomo() {
    # --- Configuration ---
    local APP_DIR="$HOME/.pomo-cli"
    local DB_FILE="$APP_DIR/pomodoro.db"
    local PID_FILE="$APP_DIR/pomo-cli.pid"

    # --- Helper: Setup directory and database ---
    _pomo_setup() {
        mkdir -p "$APP_DIR"
        if [ ! -f "$DB_FILE" ]; then
            sqlite3 "$DB_FILE" <<'EOF'
CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_name TEXT NOT NULL,
    duration_minutes INTEGER NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL
);
EOF
        fi
    }

    # --- Helper: Run the actual timer ---
    _pomo_run_timer() {
        local task_name="$1"
        local duration_minutes="$2"
        local start_time
        start_time=$(date -Iseconds) # ISO 8601 format

        echo "Timer started for '$task_name' for $duration_minutes minutes. (PID: $$)"
        
        # Trap SIGINT/SIGTERM (Ctrl+C or 'pomo stop')
        trap 'echo -e "\nTimer for '\''$task_name'\'' was stopped."; exit' INT TERM

        # Sleep for the duration
        sleep $((duration_minutes * 60))

        local end_time
        end_time=$(date -Iseconds)
        
        echo -e "Good job! You managed to complete the session for '$task_name'!\a"

        # Escape single quotes for SQL
        local task_name_sql
        task_name_sql=$(echo "$task_name" | sed "s/'/''/g")

        # Save to database
        sqlite3 "$DB_FILE" "INSERT INTO tasks (task_name, duration_minutes, start_time, end_time) VALUES ('$task_name_sql', $duration_minutes, '$start_time', '$end_time');"
        echo "Task '$task_name' saved."
    }

    # --- Main Command Logic ---
    local command="$1"
    if [[ -z "$command" ]]; then
        cat <<'EOF'
Usage: pomo <command> [options]

Commands:
  start     Start a new Pomodoro session.
    --task "task name"    (Required) The name of the task.
    --time <minutes>      (Optional) Duration in minutes. Default: 25.
    --background          (Optional) Run the timer in the background.

  stop      Stop the currently running background Pomodoro session.
  view      Show a history of completed tasks.
  stats     Display statistics about your sessions.
EOF
        return
    fi
    shift # Move past the command argument

    # Ensure everything is set up before running any command
    _pomo_setup

    case "$command" in
        "start")
            # --- Argument Parsing for 'start' ---
            local task=""
            local timer=25
            local background=false
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --task) task="$2"; shift 2 ;;
                    --time) timer="$2"; shift 2 ;;
                    --background) background=true; shift ;;
                    _internal_start) _internal_start=true; shift ;; # Hidden flag for background process
                    *) echo "Unknown option: $1"; return 1 ;;
                esac
            done
            
            if [[ -z "$task" ]]; then
                echo "Error: --task is a required flag."
                return 1
            fi

            if $background; then
                # Check if a timer is already running
                if [ -f "$PID_FILE" ]; then
                    echo "A background timer is already running. Use 'pomo stop' first."
                    return 1
                fi
                # Start the process in the background
                pomo start --task "$task" --time "$timer" _internal_start &
                local pid=$!
                echo "$pid" > "$PID_FILE"
                echo "Pomodoro timer for '$task' is running in the background. PID: $pid"
                echo "Use 'pomo stop' to end it."
            else
                _pomo_run_timer "$task" "$timer"
                # If this was a background child, remove the PID file on completion
                if [ -n "$_internal_start" ]; then
                    rm -f "$PID_FILE"
                fi
            fi
            ;;

        "stop")
            if [ ! -f "$PID_FILE" ]; then
                echo "No active Pomodoro timer found in the background."
                return
            fi
            local pid
            pid=$(cat "$PID_FILE")
            # Check if process exists before trying to kill
            if ps -p "$pid" > /dev/null; then
                kill "$pid"
                echo "Successfully stopped Pomodoro timer (PID: $pid)."
            else
                echo "Timer process (PID: $pid) not found. It might have finished already."
            fi
            rm "$PID_FILE"
            ;;

        "view")
            echo
            echo "--- Pomodoro Task History ---"
            # Use column mode and set widths for clean output
            local output
            output=$(sqlite3 -separator ' | ' "$DB_FILE" "SELECT task_name, duration_minutes, strftime('%Y-%m-%d %H:%M:%S', start_time) FROM tasks ORDER BY start_time DESC;")
            if [ -z "$output" ]; then
                echo "No tasks found in the database."
            else
                echo "$output" | while IFS= read -r line; do
                    printf -- "- %s\n" "$line"
                done
            fi
            ;;

        "stats")
            echo
            echo "--- Pomodoro Statistics ---"
            local total_sessions total_minutes avg_duration
            total_sessions=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks;")
            total_minutes=$(sqlite3 "$DB_FILE" "SELECT SUM(duration_minutes) FROM tasks;")
            avg_duration=$(sqlite3 "$DB_FILE" "SELECT AVG(duration_minutes) FROM tasks;")

            printf "Total Pomodoro Sessions: %s\n" "${total_sessions:-0}"
            printf "Total Time Spent: %s minutes\n" "${total_minutes:-0}"
            printf "Average Session Duration: %.2f minutes\n" "${avg_duration:-0}"
            
            echo
            echo "Most Frequent Tasks:"
            local frequent_tasks
            frequent_tasks=$(sqlite3 -separator ':' "$DB_FILE" "SELECT task_name, COUNT(*) AS count FROM tasks GROUP BY task_name ORDER BY count DESC LIMIT 5;")
            if [ -z "$frequent_tasks" ]; then
                echo "No tasks recorded yet."
            else
                echo "$frequent_tasks" | while IFS=: read -r task_name count; do
                    printf -- "- '%s': %s sessions\n" "$task_name" "$count"
                done
            fi
            ;;

        *)
            echo "Unknown command: $command"
            pomo # Show usage
            return 1
            ;;
    esac
}
