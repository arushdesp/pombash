# Pombash

A simple, command-line Pomodoro timer to help you focus directly from your terminal.

# Installation

## Add to your Shell

Copy the entire `pomo()` function script and paste it at the end of your `~/.bashrc` (for Bash) or `~/.zshrc` (for Zsh) file.

## Reload your Shell

Open a new terminal or run `source ~/.bashrc` (or `source ~/.zshrc`) to make the command available.

**Note:** Requires `sqlite3`. Most systems have it, but if not, install it with `sudo apt install sqlite3` or `brew install sqlite3`.

# Basic Usage

## Start a 25-minute timer for "Writing report"

```bash
pomo start --task "Writing report"
```

## Start a 5-minute timer in the background

```bash
pomo start --task "Check emails" --time 5 --background
```

### Stop the background timer

```bash
pomo stop
````

## View your history

```bash
pomo view
```

## See your stats

```bash
pomo stats
```

