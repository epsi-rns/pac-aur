#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

function get_short_arguments() {
    # get short arguments
    args=($@)
    for i in "${args[@]}"; do
        [[ "$i" =~ ^-[a-zA-Z0-9] ]] && opts+=($i)
    done
}

function set_color_arguments() {
    # color
    
    # -n : string is not null.
    # -z : string is null.
    if [[ -n "$(grep '^Color' '/etc/pacman.conf')" && $color != 'never' ]]; then
    
        # ternary operator
        [[ $color = 'always' ]] && auropts+=("--color=always") || auropts+=("--color=auto")
        
        reset="\e[0m"
        colorR="\e[1;31m"
        colorG="\e[1;32m"
        colorY="\e[1;33m"
        colorB="\e[1;34m"
        colorM="\e[1;35m"
        colorC="\e[1;36m"
        colorW="\e[1;39m"
    elif [[ -z "$(grep '^Color' '/etc/pacman.conf')" && ($color = 'always' || $color = 'auto') ]]; then
    
        pacopts+=("--color $color") && auropts+=("--color=$color")
        
        reset="\e[0m"
        colorR="\e[1;31m"
        colorG="\e[1;32m"
        colorY="\e[1;33m"
        colorB="\e[1;34m"
        colorM="\e[1;35m"
        colorC="\e[1;36m"
        colorW="\e[1;39m"
    else
        [[ $color != 'always' && $color != 'auto' ]] && makeopts+=("--nocolor")
    fi
}

function sanity_check() {
    # sanity check
    pacmanarg=(${pacmanarg[@]/--/})
    pacmanarg=(${pacmanarg[@]/-r/})
    pacmanarg=(${pacmanarg[@]/-a/})

    [[ $operation = sync && ! $search && ! $info && ! $cleancache ]] && [[ "$EUID" -eq 0 ]] && show_note "e" $"you cannot perform this operation as root"

    [[ $pacS ]] && pacmanarg=(${pacmanarg[@]/-e/})

    [[ $pacS ]] && [[ $search && $info ]] && auropts=(${auropts[@]/-i/})

    [[ $pacS ]] && [[ $cleancache ]] && unset search info upgrade

    [[ ! $(command -v "${editor%% *}") ]] && show_note "e" $"${colorW}\$VISUAL${reset} and ${colorW}\$EDITOR${reset} environment variables not set or defined ${colorW}editor${reset} not found"

    [[ "$PACMAN" = $(basename "$0") ]] && show_note "e" $"you cannot use ${colorW}pacaur${reset} as PACMAN environment variable"

    # -w : file has write permission.
    [[ ! -w "$clonedir" ]] && show_note "e" $"${colorW}$clonedir${reset} does not have write permission"
    
    # -z : string is null.
    [[ -z "${pkgs[@]}" ]] && [[ $operation = download || $operation = sync || $operation = editpkg ]] && [[ ! $refresh && ! $upgrade && ! $cleancache ]] && show_note "e" $"no targets specified (use -h for help)"

    # -z : string is null.
    [[ -z "${pkgs[@]}" && -n "$(grep -e "-[RU]" <<< ${pacmanarg[@]})" && -z "$(grep -e "-[h]" <<< ${pacmanarg[@]})" ]] && show_note "e" $"no targets specified (use -h for help)"

    [[ $repo && $aur ]] && show_note "e" $"target not found"
}

function deprecation_warning() {
    # deprecation warning
    [[ $deprecated ]] && [[ ! $quiet ]] && message_deprecated
}

# vim:set ts=4 sw=2 et:
