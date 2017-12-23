#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

# used extensively in several functions
do_proceed() {
    local Y y N n answer readline ret
    Y="$(gettext pacman Y)"; y="${Y,,}";
    N="$(gettext pacman N)"; n="${N,,}"
    if [[ "$TERM" = dumb ]] || [[ $cleancache ]]; then
        readline=1
    else
        readline=0
    fi
    case "$1" in
        y)  printf "${colorB}%s${reset} ${colorW}%s${reset}" "::" "$2 [$Y/$n] "
            if [[ $noconfirm ]]; then
                echo
                return 0
            fi
            while true; do
                if [[ $readline ]]; then
                    read -r answer
                else
                    read -s -r -n 1 answer
                fi
                case $answer in
                    $Y|$y|'') ret=0; break;;
                    $N|$n) ret=1; break;;
                    *) [[ $readline ]] && ret=1 && break;;
                esac
            done;;
        n)  printf "${colorB}%s${reset} ${colorW}%s${reset}" "::" "$2 [$y/$N] "
            if [[ $noconfirm ]]; then
                echo
                return 0
            fi
            while true; do
                if [[ $readline ]]; then
                    read -r answer
                else
                    read -s -r -n 1 answer
                fi
                case $answer in
                    $N|$n|'') ret=0; break;;
                    $Y|$y) ret=1; break;;
                    *) [[ $readline ]] && ret=0 && break;;
                esac
            done;;
    esac
    if ! [[ $readline ]]; then
        echo "$answer"
    fi
    return $ret
}

# vim:set ts=4 sw=2 et:
