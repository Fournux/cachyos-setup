#!/usr/bin/env bash
set -euo pipefail

# Read agent state payload from stdin
payload="$(cat)"
[ -z "$payload" ] && exit 0

# ANSI colors (matching OMP aesthetic)
C_RESET="\033[0m"
C_SEP="\033[38;5;239m"        # Dim dark grey for chevrons
C_MODEL="\033[38;5;81m"       # Vibrant cyan for model name
C_DOT="\033[38;5;244m"                      # Subtle grey for middle dot
C_EFFORT_LOW="\033[38;2;35;209;139m"         # Official emerald green (#23d18b) for low
C_EFFORT_MED="\033[38;2;229;229;16m"         # Official yellow (#e5e510) for medium
C_EFFORT_HIGH="\033[38;2;215;89;89m"         # Official coral red (#d75959) for high
C_FOLDER="\033[38;5;253m"      # Crisp white for directory
C_GIT="\033[38;5;48m"          # Bright green for git branch
C_CTX="\033[38;5;250m"         # Clean light grey for context %
C_CTXMODE="\033[38;5;43m"      # Soft cyan-mint for context-mode
C_ERR="\033[38;5;203m"          # Vibrant coral red for error / disabled
C_LINE="\033[38;5;238m"        # Dim trailing rule

# Powerline-thin chevron separator
SEP=" ${C_SEP}›${C_RESET} "

# Parse payload values line by line
mapfile -t fields < <(jq -r '
  def fmt_total(n):
    if n >= 1000000 then ((n / 1000000 | floor | tostring) + "M")
    elif n >= 1000 then ((n / 1000 | floor | tostring) + "k")
    else (n | tostring) end;

  def fmt_pct(p):
    (p * 10 | round / 10 | tostring) as $s |
    if ($s | contains(".")) then $s else $s + ".0" end;

  # Extract model name and effort from display_name or id
  (.model.display_name // .model.id // "Agent") as $raw_model |
  (if ($raw_model | test("\\((High|Low|Medium|high|low|medium)\\)$")) then
    {
      name: ($raw_model | sub(" \\((High|Low|Medium|high|low|medium)\\)$"; "")),
      effort: ($raw_model | capture("\\((?<e>High|Low|Medium|high|low|medium)\\)$").e | ascii_downcase)
    }
  else
    {
      name: ($raw_model | split(":")[0]),
      effort: (.effort // (.model.id // "" | split(":")[1]) // "")
    }
  end) as $m |

  $m.name,
  $m.effort,
  (.workspace.project_dir // .cwd // ""),
  (.vcs.branch // .branch // .workspace.branch // ""),
  fmt_pct(.context_window.used_percentage // 0),
  fmt_total(.context_window.context_window_size // 1048576)
' <<< "$payload" 2>/dev/null || true)

model="${fields[0]:-Agent}"
effort="${fields[1]:-}"
dir="${fields[2]:-}"
vcs_branch="${fields[3]:-}"
pct="${fields[4]:-0.0}"
total_size="${fields[5]:-1M}"

# Current directory name
dir_name="${dir##*/}"
[ -z "$dir_name" ] && dir_name="workspace"

# Git branch (use payload or probe git repository directly)
branch="$vcs_branch"
if [ -z "$branch" ] && [ -n "$dir" ] && [ -d "$dir" ]; then
  branch="$(git -C "$dir" branch --show-current 2>/dev/null || git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
fi

# Build statusline segments
out=""

# 1. Model + Thinking mode
out+="${C_MODEL} ${model}${C_RESET}"
if [ -n "$effort" ] && [ "$effort" != "null" ]; then
  effort_icon="●"
  effort_color="$C_EFFORT_HIGH"
  case "$effort" in
    low)
      effort_icon="◔"
      effort_color="$C_EFFORT_LOW"
      ;;
    medium)
      effort_icon="◐"
      effort_color="$C_EFFORT_MED"
      ;;
    high)
      effort_icon="●"
      effort_color="$C_EFFORT_HIGH"
      ;;
  esac
  out+="${C_DOT} · ${effort_color}${effort_icon} ${effort}${C_RESET}"
fi

# 2. Current directory
out+="${SEP}${C_FOLDER} ${dir_name}${C_RESET}"

# 3. Git branch (if inside a git repository)
if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
  out+="${SEP}${C_GIT} ${branch}${C_RESET}"
fi

# 4. Context usage (% / total)
out+="${SEP}${C_CTX}󰍛 ${pct}%/${total_size}${C_RESET}"

# 5. Context-mode savings / status
ctx_stats_file=""
agy_pid=""
cur=$$
for _ in 1 2 3 4 5; do
  [ -z "$cur" ] || [ "$cur" -le 1 ] && break
  cur="$(awk '{print $4}' "/proc/$cur/stat" 2>/dev/null || true)"
  if [ -n "$cur" ] && grep -qi "agy" "/proc/$cur/comm" 2>/dev/null; then
    agy_pid="$cur"
    break
  fi
done

if ! command -v context-mode >/dev/null 2>&1 || [ ! -f "$HOME/.gemini/config/plugins/context-mode/mcp_config.json" ]; then
  out+="${SEP}${C_ERR}󰘳 ctx: off${C_RESET}"
else
  if [ -n "$agy_pid" ] && [ -f "$HOME/.gemini/context-mode/sessions/stats-pid-${agy_pid}.json" ]; then
    ctx_stats_file="$HOME/.gemini/context-mode/sessions/stats-pid-${agy_pid}.json"
  fi

  if [ -n "$ctx_stats_file" ] && [ -f "$ctx_stats_file" ]; then
    ctx_pct="$(jq -r '.reduction_pct // 0' "$ctx_stats_file" 2>/dev/null || echo "err")"
    if [ "$ctx_pct" = "err" ]; then
      out+="${SEP}${C_ERR}󰘳 ctx: error${C_RESET}"
    elif [ "$ctx_pct" -gt 0 ] 2>/dev/null; then
      out+="${SEP}${C_CTXMODE}󰘳 ctx: ${ctx_pct}% saved${C_RESET}"
    else
      out+="${SEP}${C_CTXMODE}󰘳 ctx: active${C_RESET}"
    fi
  else
    # Without stats tied to this process, do not report another session's savings.
    out+="${SEP}${C_CTXMODE}󰘳 ctx: ready${C_RESET}"
  fi
fi

# 6. Trailing rule
out+=" ${C_LINE}──────${C_RESET}"

echo -e "$out"
