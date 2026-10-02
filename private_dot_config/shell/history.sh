# Shared interactive history setup for Bash and Zsh.
# Shell-managed variables and optional, runtime-sourced integrations:
# shellcheck disable=SC2034,SC1091
# McFly is a local search index, not the lossless archive: it skips some commands.
case $- in *i*) ;; *) return 0 ;; esac
[ -z "${_dotfiles_history_loaded:-}" ] || return 0
_dotfiles_history_loaded=1

_dotfiles_history_preexec() {
    _dotfiles_history_command=$1
    _dotfiles_history_directory=$PWD
    _dotfiles_history_when=$(date +%s)

    # One writer per file, append-only, no expiry. %q preserves multiline commands
    # and whitespace on one line without evaluating any command text.
    printf '%s\t%q\t%q\n' "$_dotfiles_history_when" \
        "$_dotfiles_history_directory" "$_dotfiles_history_command" \
        >> "$_dotfiles_history_archive" ||
        printf 'WARNING: could not archive shell history\n' >&2

    # Save before execution, including exit/exec and commands interrupted by a
    # killed terminal. Zsh already writes incrementally via SHARE_HISTORY.
    if [ -n "${BASH_VERSION:-}" ]; then
        builtin history -a
    fi
    return 0
}

_dotfiles_history_precmd() {
    local exit_code=$?
    if [ -n "${_dotfiles_history_command:-}" ]; then
        if [ "${_dotfiles_history_mcfly:-0}" = 1 ]; then
            # Pass the whole command explicitly: McFly's stock hooks read only
            # the last physical line, and can misattribute shared Zsh history.
            (umask 077; "$MCFLY_PATH" --history_format "$MCFLY_HISTORY_FORMAT" \
                add --exit "$exit_code" --when "$_dotfiles_history_when" \
                --dir "$_dotfiles_history_directory" \
                -- "$_dotfiles_history_command") ||
                printf 'WARNING: McFly indexing failed; command is in the local archive\n' >&2
            # Bash 3.2's Ctrl-R macro passes its query through this temporary
            # buffer. Do not use it as the source of truth for recording.
            (umask 077; printf '%s\n' "$_dotfiles_history_command" > "$MCFLY_HISTORY")
        fi
        _dotfiles_history_command=
    fi
    if [ -n "${BASH_VERSION:-}" ]; then
        # Append only. McFly searches across sessions without history -c/-r/-n,
        # which can lose/duplicate entries with Bash 3.2 and multiline history.
        builtin history -a
    fi
    return "$exit_code"
}

_dotfiles_history_init() {
    local shell_name archive_dir mcfly_init
    # Disable macOS Terminal's separate, expiring per-window history mechanism.
    SHELL_SESSION_HISTORY=0
    if [ -n "${ZSH_VERSION:-}" ]; then
        shell_name=zsh
        HISTFILE="$HOME/.zsh_history"
        HISTSIZE=200000
        SAVEHIST=100000
        setopt APPEND_HISTORY SHARE_HISTORY EXTENDED_HISTORY HIST_FCNTL_LOCK HIST_SAVE_BY_COPY
        unsetopt INC_APPEND_HISTORY INC_APPEND_HISTORY_TIME HIST_IGNORE_SPACE \
            HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS \
            HIST_EXPIRE_DUPS_FIRST HIST_REDUCE_BLANKS HIST_NO_STORE
    else
        shell_name=bash
        HISTFILE="$HOME/.bash_history"
        HISTSIZE=100000
        # Unset means no on-disk truncation, including Bash 3.2 on macOS.
        unset HISTFILESIZE
        HISTCONTROL=
        HISTIGNORE=
        HISTTIMEFORMAT='%F %T '
        shopt -s histappend cmdhist lithist
    fi

    archive_dir="${XDG_STATE_HOME:-$HOME/.local/state}/shell-history"
    (umask 077; mkdir -p "$archive_dir" && touch "$HISTFILE" &&
        chmod 700 "$archive_dir" && chmod 600 "$HISTFILE") ||
        printf 'WARNING: could not secure shell history files\n' >&2
    # Preserve pre-existing history before any native size limits take effect.
    # Never replace this snapshot when another terminal starts.
    if [ ! -e "$archive_dir/$shell_name.before.history" ]; then
        (umask 077; cp -n "$HISTFILE" "$archive_dir/$shell_name.before.history")
    fi
    _dotfiles_history_archive=$(mktemp "$archive_dir/$shell_name.$(date -u +%Y%m%dT%H%M%SZ).log.XXXXXXXX")

    case "$(hostname)" in
        *linkedin.biz|*linkedin.com)
            if command -v mcfly >/dev/null 2>&1; then
                # Use McFly's supported legacy directory for one predictable,
                # private database location on both macOS and Linux.
                (umask 077; mkdir -p "$HOME/.mcfly" && chmod 700 "$HOME/.mcfly")
                unset MCFLY_HISTORY MCFLY_SESSION_ID MCFLY_PATH MCFLY_HISTORY_LIMIT
                export MCFLY_FUZZY=2
                export MCFLY_RESULTS_SORT=LAST_RUN
                export MCFLY_HISTORY_FORMAT
                # Keep the upstream search UI, but replace its lossy recording
                # hooks with our preexec/precmd pair and native file handling.
                if [ "$shell_name" = zsh ]; then
                    local -a saved_precmd_functions
                    saved_precmd_functions=("${precmd_functions[@]}")
                    eval "$(mcfly init zsh)"
                    precmd_functions=("${saved_precmd_functions[@]}")
                else
                    local -a saved_prompt_command
                    saved_prompt_command=("${PROMPT_COMMAND[@]}")
                    mcfly_init=$(mcfly init bash)
                    # Upstream 0.9.4 uses GNU-only --dry-run; -u also works with
                    # macOS mktemp. This is only for the UI's temporary filename.
                    eval "${mcfly_init//mktemp --dry-run/mktemp -u}"
                    if (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1) )); then
                        PROMPT_COMMAND=("${saved_prompt_command[@]}")
                    else
                        # Bash < 5.1 only executes a scalar PROMPT_COMMAND.
                        # shellcheck disable=SC2178
                        PROMPT_COMMAND=${saved_prompt_command[0]}
                    fi
                    export MCFLY_HISTORY_FORMAT=bash
                    MCFLY_HISTORY=$(mktemp "${TMPDIR:-/tmp}/mcfly.XXXXXXXX")
                    export MCFLY_HISTORY
                    # McFly defaults to ignorespace; the archive keeps everything.
                    HISTCONTROL=
                fi
                if [ -n "${MCFLY_PATH:-}" ]; then
                    _dotfiles_history_mcfly=1
                    # Initialize/import before the first command, with private
                    # permissions. No sync, daemon, or network service is used.
                    if [ ! -f "$HOME/.mcfly/history.db" ]; then
                        (umask 077; "$MCFLY_PATH" --history_format "$MCFLY_HISTORY_FORMAT" add -- '')
                    fi
                fi
            fi
            ;;
        *)
            # Atuin is never invoked (even for init) on LinkedIn hosts.
            [ ! -f "$HOME/.atuin/bin/env" ] || . "$HOME/.atuin/bin/env"
            if command -v atuin >/dev/null 2>&1; then
                eval "$(atuin init "$shell_name")"
            fi
            ;;
    esac

    if [ "$shell_name" = zsh ]; then
        autoload -Uz add-zsh-hook
        add-zsh-hook preexec _dotfiles_history_preexec
        add-zsh-hook precmd _dotfiles_history_precmd
    else
        # Use the existing framework rather than replacing DEBUG/PROMPT_COMMAND;
        # this preserves Atuin, direnv, existing prompt hooks, and exit status.
        preexec_functions+=(_dotfiles_history_preexec)
        precmd_functions+=(_dotfiles_history_precmd)
    fi
}

# Source at top level: bash-preexec uses `declare`, which would otherwise make
# its hook arrays local to our initializer and discard them when it returns.
if [ -n "${BASH_VERSION:-}" ]; then
    . "$HOME/.bash-preexec.sh"
fi
_dotfiles_history_init
unset -f _dotfiles_history_init
