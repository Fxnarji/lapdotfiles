# Same prompt as the bash one: grey working directory, red ❯.
function fish_prompt
    set_color brblack
    echo -n (string replace -r "^$HOME" '~' $PWD)' '
    set_color red
    echo -n '❯ '
    set_color normal
end
