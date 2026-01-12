# Default theme

# ------------------------------------------------------------------------------
# Initialization
# ------------------------------------------------------------------------------

# Enable true color / 256 color support availability
autoload -U colors && colors

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

# Define palette using %F{code} for 256 colors where possible
typeset -gA theme_colors
theme_colors=(
  "repo"           "%F{cyan}%B"    # Cyan Bold (Anchor)
  "path_dim"       "%F{8}"         # Grey (Intermediate)
  "path_leaf"      "%F{white}%B"   # White Bold (Focus)
  "slash"          "%F{white}"     # White
  "cyan"           "%F{cyan}"      # Cyan
  "blue"           "%F{blue}"      # Blue
  "red"            "%F{red}"       # Red
  "green"          "%F{green}"     # Green
  "yellow"         "%F{yellow}"    # Yellow
  "purple"         "%F{magenta}"   # Purple
  "reset"          "%f%b"          # Reset
)

# Icons
typeset -gA icons
icons=(
  "branch"    ""
  "dirty"     "󰦒"
  "staged"    "󰐕"
  "untracked" "󰦒"
  "ahead"     ""
  "behind"    ""
  "chevron"   "❯"
)

# Hook system
[[ -z "$__toon_theme_hooks_set" ]] && {
  __toon_theme_hooks_set=1
  precmd_functions+=(toon_precmd)
}

toon_precmd() {
  __cmd_exit_status=$?
}

# ------------------------------------------------------------------------------
# Utilities
# ------------------------------------------------------------------------------

__get_git_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

# ------------------------------------------------------------------------------
# Segments
# ------------------------------------------------------------------------------

# Smart Path
# - Non-Git: ~/.../dimmed/leaf/
# - Git: repo(highlight)/dimmed/sub/leaf(highlight)/
__build_path_segment() {
  local cwd="$PWD"
  local git_root="$(__get_git_root)"
  local output=""

  if [[ -z "$git_root" ]]; then
    # --- Outside Git ---
    # Replace $HOME with ~
    local pretty_path="${cwd/#$HOME/~}"
    
    if [[ "$pretty_path" == "~" ]]; then
       output="${theme_colors[path_dim]}%B~${theme_colors[reset]}"
    elif [[ "$pretty_path" == "/" ]]; then
       output="${theme_colors[path_leaf]}/${theme_colors[reset]}"
    else
       local dir_head="${pretty_path:h}"
       local dir_tail="${pretty_path:t}"
       
       if [[ "$dir_head" == "." || "$dir_head" == "/" || "$dir_head" == "~" ]]; then
          [[ "$dir_head" != "." ]] && output="${theme_colors[path_dim]}$dir_head/${theme_colors[reset]}"
          output+="${theme_colors[path_leaf]}$dir_tail${theme_colors[reset]}"
       else
          output="${theme_colors[path_dim]}$dir_head/${theme_colors[reset]}${theme_colors[path_leaf]}$dir_tail${theme_colors[reset]}"
       fi
    fi
  else
    # --- Inside Git ---
    local repo_name="${git_root##*/}"
    local subpath="${cwd#$git_root}"
    
    # 1. Repo Name (Anchor)
    output="${theme_colors[repo]}$repo_name${theme_colors[reset]}"
    
    # 2. Subpath
    if [[ -n "$subpath" && "$subpath" != "/" ]]; then
      # Strip leading slash and split
      local parts=("${(@s:/:)subpath#/}")
      local last_idx="${#parts}"
      local i=0

      for part in $parts; do
        ((i++))
        output+="${theme_colors[path_dim]}/${theme_colors[reset]}"
        if [[ $i -eq $last_idx ]]; then
          output+="${theme_colors[path_leaf]}$part${theme_colors[reset]}"
        else
          output+="${theme_colors[path_dim]}$part${theme_colors[reset]}"
        fi
      done
    fi
  fi

  echo "$output"
}

# Git Status (High Performance)
__build_git_segment() {
  # Check if in git using built-ins
  [[ -z "$(git rev-parse --git-dir 2>/dev/null)" ]] && return

  local git_status_out
  # Use --porcelain for easy parsing
  git_status_out=$(git status --porcelain -b 2>/dev/null)
  
  # Parse Branch
  local branch_line="${git_status_out%%$'\n'*}" # First line
  local branch_name="${branch_line##\#\# }" # Remove ##
  branch_name="${branch_name%%...*}"        # Remove tracking info
  
  # Parse Counts
  local dirty_c=$(grep -c "^.M" <<< "$git_status_out")
  local staged_c=$(grep -c "^[MA]" <<< "$git_status_out")
  local untracked_c=$(grep -c "^??" <<< "$git_status_out")
  
  # Parse Ahead/Behind
  local ahead_c=0
  local behind_c=0
  [[ "$branch_line" =~ "ahead ([0-9]+)" ]] && ahead_c=$match[1]
  [[ "$branch_line" =~ "behind ([0-9]+)" ]] && behind_c=$match[1]

  # Build Output
  local flags=""
  [[ $ahead_c -gt 0 ]] && flags+=" ${theme_colors[cyan]}${icons[ahead]}$ahead_c${theme_colors[reset]}"
  [[ $behind_c -gt 0 ]] && flags+=" ${theme_colors[repo]}${icons[behind]}$behind_c${theme_colors[reset]}"
  
  local status_icon=""
  if [[ $staged_c -gt 0 && $dirty_c -eq 0 && $untracked_c -eq 0 ]]; then
    status_icon="${theme_colors[green]}${icons[staged]}${theme_colors[reset]}"
  elif [[ $dirty_c -gt 0 || $untracked_c -gt 0 ]]; then
    status_icon="${theme_colors[yellow]}${icons[dirty]}${theme_colors[reset]}"
  else
    status_icon="${theme_colors[blue]}${icons[branch]}${theme_colors[reset]}"
  fi
  
  local branch_color="${theme_colors[blue]}"
  [[ "$branch_name" == "main" ]] && branch_color="${theme_colors[purple]}"
  
  echo "${branch_color}$branch_name $status_icon${theme_colors[reset]}$flags"
}

# Date Time (Right Prompt)
__build_rprompt() {
  # Git
  local git="$(__build_git_segment)"
  
  # Clock: White Normal Text, White Colon
  local time_fmt="${theme_colors[white]}%D{%H}${theme_colors[white]}:${theme_colors[white]}%D{%M}${theme_colors[white]}:${theme_colors[white]}%D{%S}${theme_colors[reset]}"
  
  # Date: Yellow Dim
  local date_fmt="${theme_colors[yellow]}%D{%Y-%m-%d}${theme_colors[reset]}"
  
  echo "$git $time_fmt $date_fmt"
}

# Main Prompt
__build_prompt() {
  local segments=""
  
  # 1. Path
  segments+="$(__build_path_segment)"
  
  # 2. Chevron (Color based on status)
  local chev_color="${theme_colors[green]}"
  [[ $__cmd_exit_status -ne 0 ]] && chev_color="${theme_colors[red]}"
  
  echo "$segments ${chev_color}${icons[chevron]}${theme_colors[reset]} "
}

# ------------------------------------------------------------------------------
# Set Prompts
# ------------------------------------------------------------------------------

# Use single quotes to defer execution to render time
PROMPT='$(__build_prompt)'
RPROMPT='$(__build_rprompt)'
setopt transient_rprompt
