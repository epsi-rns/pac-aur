#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

show_note() {
    case "$1" in
        i) echo -e "${colorB}::${reset} $2";;       # info
        s) echo -e "${colorG}::${reset} $2";;       # success
        w) echo -e "${colorY}::${reset} $2";;       # warn
        f) echo -e "${colorR}::${reset} $2" >&2;;   # fail
        e) echo -e "${colorR}::${reset} $2" >&2;    # error
           exit 1;;
    esac
}

helper_get_length() {
    local length=0 i
    for i in "$@"; do
        x=${#i}
        [[ $x -gt $length ]] && length=$x
    done
    echo $length
}

nothing_to_do() {
    [[ -z "$@" ]] && printf "%s\n" $" there is nothing to do" && exit || return 0
}

# vim:set ts=4 sw=2 et:
