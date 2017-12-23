#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

function ignore_checks() {
    local checkaurpkgs checkaurpkgsAver checkaurpkgsAgrp checkaurpkgsQver checkaurpkgsQgrp i json
    # global aurpkgs rmaurpkgs
    [[ -z "${ignoredpkgs[@]}" && -z "${ignoredgrps[@]}" ]] && return

    # remove AUR pkgs versioning
    for i in "${!aurpkgs[@]}"; do
        aurpkgsnover[$i]=$(awk -F ">|<|=" '{print $1}' <<< ${aurpkgs[$i]})
    done

    # check targets
    set_json ${aurpkgsnover[@]}
    checkaurpkgs=($(get_json "var" "$json" "Name"))
    errdeps+=($(grep -xvf <(printf '%s\n' "${aurpkgsnover[@]}") <(printf '%s\n' "${checkaurpkgs[@]}")))
    errdeps+=($(grep -xvf <(printf '%s\n' "${checkaurpkgs[@]}") <(printf '%s\n' "${aurpkgsnover[@]}")))
    unset aurpkgsnover

    checkaurpkgsAver=($(get_json "var" "$json" "Version"))
    checkaurpkgsQver=($(expac -Q '%v' "${checkaurpkgs[@]}"))
    for i in "${!checkaurpkgs[@]}"; do
        [[ -n "$(grep -E "\-(cvs|svn|git|hg|bzr|darcs|daily.*|nightly.*)$" <<< ${checkaurpkgs[$i]})" ]] && checkaurpkgsAver[$i]=$"latest"
    done
    for i in "${!checkaurpkgs[@]}"; do
        unset isignored
        if [[ " ${ignoredpkgs[@]} " =~ " ${checkaurpkgs[$i]} " ]]; then
            isignored=true
        elif [[ -n "${ignoredgrps[@]}" ]]; then
            unset checkaurpkgsAgrp checkaurpkgsQgrp
            checkaurpkgsAgrp=($(get_json "arrayvar" "$json" "Groups" "${checkaurpkgs[$i]}"))
            for j in "${checkaurpkgsAgrp[@]}"; do
                [[ " ${ignoredgrps[@]} " =~ " $j " ]] && isignored=true
            done
            checkaurpkgsQgrp=($(expac -Q '%G' "${checkaurpkgs[$i]}"))
            for j in "${checkaurpkgsQgrp[@]}"; do
                [[ " ${ignoredgrps[@]} " =~ " $j " ]] && isignored=true
            done
        fi

        if [[ $isignored = true ]]; then
            if [[ ! $upgrade ]]; then
                if [[ ! $noconfirm ]]; then
                    if ! do_proceed "y" $"${checkaurpkgs[$i]} is in IgnorePkg/IgnoreGroup. Install anyway?"; then
                        show_note "w" $"skipping target: ${colorW}${checkaurpkgs[$i]}${reset}"
                        rmaurpkgs+=(${checkaurpkgs[$i]})
                        continue
                    fi
                else
                    show_note "w" $"skipping target: ${colorW}${checkaurpkgs[$i]}${reset}"
                    rmaurpkgs+=(${checkaurpkgs[$i]})
                    continue
                fi
            else
                show_note "w" $"${colorW}${checkaurpkgs[$i]}${reset}: ignoring package upgrade (${colorR}${checkaurpkgsQver[$i]}${reset} => ${colorG}${checkaurpkgsAver[$i]}${reset})"
                rmaurpkgs+=(${checkaurpkgs[$i]})
                continue
            fi
        fi
        aurpkgsnover+=(${checkaurpkgs[$i]})
    done

    aurpkgs=(${aurpkgsnover[@]})
    nothing_to_do ${aurpkgs[@]}
}

# vim:set ts=4 sw=2 et:
