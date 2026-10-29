# Ported from ~/.bashrc (bash stays the login shell; kitty starts fish).

fish_add_path -g ~/.local/bin

if status is-interactive
    set -g fish_greeting   # no welcome text

    alias grep 'grep --color=auto'
    alias ll 'ls -lh'
    alias timer 'tclock timer -d 25m -c Red -M'
    alias clock 'tclock clock -c White'
    alias p python3

    # kitten ssh copies kitty's terminfo to the host, so the remote shell
    # understands kitty (colours, keys, clear). Only inside kitty.
    if test "$TERM" = xterm-kitty
        alias ssh 'kitten ssh'
    end

    # zoxide: `z foo` jumps to the most-used dir matching foo, `zi` picks with fzf
    zoxide init fish | source

    # fastfetch once per new kitty window (not in nested shells)
    if test "$TERM" = xterm-kitty; and not set -q FASTFETCH_SHOWN
        set -gx FASTFETCH_SHOWN 1
        fastfetch
    end
end
