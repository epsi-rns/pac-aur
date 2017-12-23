#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

function check_updates() {
    local foreignpkgs foreignpkgsbase repopkgsQood repopkgsQver repopkgsSver repopkgsSrepo repopkgsQgrp repopkgsQignore
    local aurpkgsQood aurpkgsAname aurpkgsAver aurpkgsQver aurpkgsQignore i json
    local aurdevelpkgsAver aurdevelpkgsQver aurpkgsQoodAver lname lQver lSver lrepo lgrp lAname lAQver lASver lArepo

    get_ignored_pkgs

    if [[ ! "${opts[@]}" =~ "n" && ! " ${pacopts[@]} " =~ --native && $fallback = true ]]; then
        [[ -z "${pkgs[@]}" ]] && foreignpkgs=($($pacmanbin -Qmq)) || foreignpkgs=(${pkgs[@]})
        if [[ -n "${foreignpkgs[@]}" ]]; then
            set_json ${foreignpkgs[@]}
            aurpkgsAname=($(get_json "var" "$json" "Name"))
            aurpkgsAver=($(get_json "var" "$json" "Version"))
            aurpkgsQver=($(expac -Q '%v' ${aurpkgsAname[@]}))
            for i in "${!aurpkgsAname[@]}"; do
                [[ $(vercmp "${aurpkgsAver[$i]}" "${aurpkgsQver[$i]}") -gt 0 ]] && aurpkgsQood+=(${aurpkgsAname[$i]});
            done
        fi

        # add devel packages
        if [[ $devel ]]; then
            if [[ ! $needed ]]; then
                for i in "${foreignpkgs[@]}"; do
                    [[ -n "$(grep -E "\-(cvs|svn|git|hg|bzr|darcs|daily.*|nightly.*)$" <<< $i)" ]] && aurpkgsQood+=($i)
                done
            else
                foreignpkgsbase=($(expac -Q '%n %e' ${foreignpkgs[@]} | awk '{if ($2 == "(null)") print $1; else print $2}'))
                foreignpkgsnobase=($(expac -Q '%n' ${foreignpkgs[@]}))
                for i in "${!foreignpkgsbase[@]}"; do
                    if [[ -n "$(grep -E "\-(cvs|svn|git|hg|bzr|darcs|daily.*|nightly.*)$" <<< ${foreignpkgsbase[$i]})" ]]; then
                        [[ ! -d "$clonedir/${foreignpkgsbase[$i]}" ]] && DownloadPkgs "${foreignpkgsbase[$i]}" &>/dev/null
                        cd "$clonedir/${foreignpkgsbase[$i]}"
                        # silent extraction and pkgver update only
                        makepkg -od --noprepare --skipinteg &>/dev/null
                        # retrieve updated version
                        aurdevelpkgsAver=($(makepkg --packagelist | awk -F "-" '{print $(NF-2)"-"$(NF-1)}'))
                        aurdevelpkgsAver=${aurdevelpkgsAver[0]}
                        aurdevelpkgsQver=$(expac -Qs '%v' "^${foreignpkgsbase[$i]}$" | head -1)
                        if [[ $(vercmp "$aurdevelpkgsQver" "$aurdevelpkgsAver") -ge 0 ]]; then
                            continue
                        else
                            aurpkgsQood+=(${foreignpkgsnobase[$i]})
                            aurpkgsQoodAver+=($aurdevelpkgsAver)
                        fi
                    fi
                done
            fi
        fi

        if [[ -n "${aurpkgsQood[@]}" && ! $quiet ]]; then
            set_json ${aurpkgsQood[@]}
            aurpkgsAname=($(get_json "var" "$json" "Name"))
            aurpkgsAname=($(expac -Q '%n' "${aurpkgsAname[@]}"))
            aurpkgsAver=($(get_json "var" "$json" "Version"))
            aurpkgsQver=($(expac -Q '%v' "${aurpkgsAname[@]}"))
            for i in "${!aurpkgsAname[@]}"; do
                [[ " ${ignoredpkgs[@]} " =~ " ${aurpkgsAname[$i]} " ]] && aurpkgsQignore[$i]=$"[ ignored ]"
                if [[ -n "$(grep -E "\-(cvs|svn|git|hg|bzr|darcs|daily.*|nightly.*)$" <<< ${aurpkgsAname[$i]})" ]]; then
                    [[ ! $needed ]] && aurpkgsAver[$i]=$"latest" || aurpkgsAver[$i]=${aurpkgsQoodAver[$i]}
                fi
            done
            lAname=$(helper_get_length "${aurpkgsAname[@]}")
            lAQver=$(helper_get_length "${aurpkgsQver[@]}")
            lASver=$(helper_get_length "${aurpkgsAver[@]}")
            lArepo=3
        fi
    fi

    if [[ ! "${opts[@]}" =~ "m" && ! " ${pacopts[@]} " =~ --foreign ]]; then
        [[ -n "${pkgs[@]}" ]] && pkgs=($(expac -Q '%n' "${pkgs[@]}"))
        repopkgsQood=($($pacmanbin -Qunq ${pkgs[@]}))

        if [[ -n "${repopkgsQood[@]}" && ! $quiet ]]; then
            repopkgsQver=($(expac -Q '%v' "${repopkgsQood[@]}"))
            repopkgsSver=($(expac -S -1 '%v' "${repopkgsQood[@]}"))
            repopkgsSrepo=($(expac -S -1 '%r' "${repopkgsQood[@]}"))
            repopkgsQgrp=($(expac -Qv -l "#" '(%G)' "${repopkgsQood[@]}"))
            for i in "${!repopkgsQood[@]}"; do
                [[ "${repopkgsQgrp[$i]}" = '(None)' ]] && unset repopkgsQgrp[$i] || repopkgsQgrp[$i]=$(tr '#' ' ' <<< ${repopkgsQgrp[$i]})
                [[ " ${ignoredpkgs[@]} " =~ " ${repopkgsQood[$i]} " ]] && repopkgsQignore[$i]=$"[ ignored ]"
            done
            lname=$(helper_get_length "${repopkgsQood[@]}")
            lQver=$(helper_get_length "${repopkgsQver[@]}")
            lSver=$(helper_get_length "${repopkgsSver[@]}")
            lrepo=$(helper_get_length "${repopkgsSrepo[@]}")
            lgrp=$(helper_get_length "${repopkgsQgrp[@]}")
        fi
    fi

    if [[ -n "${aurpkgsQood[@]}" && ! $quiet ]]; then
        [[ $lAname -gt $lname ]] && lname=$lAname
        [[ $lAQver -gt $lQver ]] && lQver=$lAQver
        [[ $lASver -gt $lSver ]] && lSver=$lASver
    fi

    if [[ -n "${repopkgsQood[@]}" ]]; then
        exitrepo=$?
        if [[ ! $quiet ]]; then
            for i in "${!repopkgsQood[@]}"; do
                printf "${colorB}::${reset} ${colorM}%-${lrepo}s${reset}  ${colorW}%-${lname}s${reset}  ${colorR}%-${lQver}s${reset}  ->  ${colorG}%-${lSver}s${reset}  ${colorB}%-${lgrp}s${reset}  ${colorY}%s${reset}\n" "${repopkgsSrepo[$i]}" "${repopkgsQood[$i]}" "${repopkgsQver[$i]}" "${repopkgsSver[$i]}" "${repopkgsQgrp[$i]}" "${repopkgsQignore[$i]}"
            done
        else
            tr ' ' '\n' <<< ${repopkgsQood[@]}
        fi
    fi
    if [[ -n "${aurpkgsQood[@]}" && $fallback = true ]]; then
        exitaur=$?
        if [[ ! $quiet ]]; then
            for i in "${!aurpkgsAname[@]}"; do
                printf "${colorB}::${reset} ${colorM}%-${lrepo}s${reset}  ${colorW}%-${lname}s${reset}  ${colorR}%-${lQver}s${reset}  ->  ${colorG}%-${lSver}s${reset}  ${colorB}%-${lgrp}s${reset}  ${colorY}%s${reset}\n" "aur" "${aurpkgsAname[$i]}" "${aurpkgsQver[$i]}" "${aurpkgsAver[$i]}" " " "${aurpkgsQignore[$i]}"
            done
        else
            tr ' ' '\n' <<< ${aurpkgsQood[@]} | sort -u
        fi
    fi
    # exit code
    if [[ -n "$exitrepo" && -n "$exitaur" ]]; then
        [[ $exitrepo -eq 0 || $exitaur -eq 0 ]] && exit 0 || exit 1
    elif [[ -n "$exitrepo" ]]; then
        [[ $exitrepo -eq 0 ]] && exit 0 || exit 1
    elif [[ -n "$exitaur" ]]; then
        [[ $exitaur -eq 0 ]] && exit 0 || exit 1
    else
        exit 1
    fi
}

# vim:set ts=4 sw=2 et:
