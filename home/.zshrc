# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   Z S H R C                                                              │
# │   interactive shell · plugins, path, prompt and tools                    │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

# Every external tool is guarded, so a missing one does not print an error
# at every prompt.


# ── OH MY ZSH ───────────────────────────────────────────────────────────────

export ZSH="$HOME/.oh-my-zsh"

# · no theme: starship sets the prompt
ZSH_THEME=""
DISABLE_COMPFIX="true"
ZSH_DISABLE_COMPFIX=true

# · zsh-autosuggestions and zsh-syntax-highlighting are cloned into
#   $ZSH/custom/plugins by ./setup
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

# · completions shipped here (cajlatland's); oh-my-zsh runs compinit, so before it
fpath=("$HOME/.local/share/zsh/site-functions" $fpath)

[[ -r $ZSH/oh-my-zsh.sh ]] && source $ZSH/oh-my-zsh.sh


# ── HISTORY ─────────────────────────────────────────────────────────────────

# · oh-my-zsh only sets hist_ignore_dups (consecutive repeats); keep just the
#   most recent copy of each command
setopt hist_ignore_all_dups


# ── PATH ────────────────────────────────────────────────────────────────────

# · no duplicates when shells are nested; the first occurrence wins
typeset -U path PATH

# · MATLAB, any installed version
for matlab_bin in /usr/local/MATLAB/*/bin(N); do
    export PATH="$matlab_bin:$PATH"
done
unset matlab_bin

# · last, so it takes precedence
export PATH="$HOME/.local/bin:$PATH"


# ── ENVIRONMENT ─────────────────────────────────────────────────────────────

# · nvim, else vim, else leave unset so programs use their built-in default
for _editor in nvim vim; do
    if (( $+commands[$_editor] )); then
        export EDITOR=$_editor
        export VISUAL=$_editor
        break
    fi
done
unset _editor


# ── PROMPT ──────────────────────────────────────────────────────────────────

# · after oh-my-zsh, so it replaces any theme
if (( $+commands[starship] )); then
    ztheme() {
        local dir="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/prompt" tmp
        if (( $# == 0 )); then
            print -r -- cajlatland
            starship preset --list
            return
        fi
        (( $# == 1 )) || return 2
        mkdir -p -- "$dir" || return 1
        if [[ $1 == cajlatland ]]; then
            command rm -f -- "$dir/active.toml" || return 1
            unset STARSHIP_CONFIG
        else
            tmp=$(mktemp "$dir/theme.XXXXXXXX") || return 1
            if starship preset -- "$1" > "$tmp" && mv -f -- "$tmp" "$dir/active.toml"; then
                export STARSHIP_CONFIG="$dir/active.toml"
            else
                command rm -f -- "$tmp"
                return 1
            fi
        fi
    }
    if [[ -s ${XDG_CONFIG_HOME:-$HOME/.config}/zsh/prompt/active.toml ]]; then
        export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/prompt/active.toml"
    fi
    eval "$(starship init zsh)"
fi


# ── TOOLS ───────────────────────────────────────────────────────────────────

# · node version manager, lazy-loaded so new terminals open without delay
if (( $+commands[fnm] )); then
    _cajlat_load_fnm() {
        unfunction fnm node npm npx pnpm yarn corepack 2>/dev/null
        eval "$(fnm env --use-on-cd)"
    }
    for _fnm_cmd in fnm node npm npx pnpm yarn corepack; do
        eval "${_fnm_cmd}() { _cajlat_load_fnm && ${_fnm_cmd} \"\$@\"; }"
    done
    unset _fnm_cmd
fi

# · fzf key bindings (ctrl-r, ctrl-t, alt-c); after the plugins that also
#   bind keys
if (( $+commands[fzf] )); then
    eval "$(fzf --zsh)"
fi

# · zoxide: adds `z` and `zi`, leaves cd alone
if (( $+commands[zoxide] )); then
    eval "$(zoxide init zsh)"
fi

# · yazi, leaving the shell in the directory it was closed in
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}


# ── ALIASES ─────────────────────────────────────────────────────────────────

alias cls="clear"

# · fastfetch with the greeting scene chosen in the settings. fastfetch's
#   config points at the chosen scene; "random" is resolved here. `fa koi`
#   forces a scene.
function fa() {
    local dir="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell" choice=""
    if [[ -n "$1" && "$1" != -* ]]; then
        if [[ ! -f "$dir/greeting-$1.gif" ]]; then
            print -u2 "fa: no scene called $1 — lava, critters, koi, invaders"
            return 1
        fi
        fastfetch --logo "$dir/greeting-$1.gif"
        return
    fi
    [[ -r "$dir/greeting" ]] && choice="$(<"$dir/greeting")"
    local scenes=("$dir"/greeting-*.gif(N))
    if [[ "$choice" == random ]] && (( $#scenes )); then
        fastfetch --logo "${scenes[RANDOM % $#scenes + 1]}" "$@"
    else
        fastfetch "$@"
    fi
}

# · The terminal toys below draw in ANSI colours, so they follow the kitty
#   palette with nothing generated. Cyan (6/14) carries the accent.

# · -l m: unimatrix's own Matrix character set
alias matrix="unimatrix -c cyan -s 96 -l m"

# · -k is dark leaves, dark wood, light leaves, light wood
alias bonsai="cbonsai -l -k 6,3,14,11"

# · centred, with seconds, and immune to stray keypresses
alias clock="tty-clock -c -s -n -C 6"

# · a lava lamp in a gradient from the accent to its bright shade, read from
#   kitty at launch, with gravity; ANSI cyan where there is no kitty to ask
lava() {
  local -A slot
  local name value
  kitten @ get-colors 2>/dev/null | while read -r name value; do slot[$name]=${value#\#}; done
  if [[ -n ${slot[color6]} && -n ${slot[color14]} ]]; then
    lavat -g -G -c "${slot[color6]}" -k "${slot[color14]}" "$@"
  else
    lavat -G -c cyan "$@"
  fi
}


# ── LOCAL ───────────────────────────────────────────────────────────────────

# · machine-specific settings, outside the repository
if [[ -r ~/.zshrc.local ]]; then
    source ~/.zshrc.local
elif [[ -o interactive ]] && command -v fastfetch >/dev/null; then
    fastfetch
fi
