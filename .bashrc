#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
export PATH="$HOME/.local/bin:$PATH"

# --- rice ---
PS1='\[\e[90m\]\w \[\e[31m\]❯\[\e[0m\] '
alias ll='ls -lh'
alias timer='tclock timer -d 25m -c Red -M'
alias clock='tclock clock -c White'

# zoxide: `z foo` jumps to the most-used dir matching foo, `zi` picks with fzf
eval "$(zoxide init bash)"

# fastfetch once per new kitty window (not in nested shells)
if [[ $TERM == xterm-kitty && -z $FASTFETCH_SHOWN ]]; then
    export FASTFETCH_SHOWN=1
    fastfetch
fi
