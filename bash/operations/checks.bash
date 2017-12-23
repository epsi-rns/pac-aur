#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

# used intensively (eight times) in this mpdule
function check_requires() {
    local Qrequires
    Qrequires=($(expac -Q '%n %D' | grep -E " $@[\+]*[^a-zA-Z0-9_@\.\+-]+" | awk '{print $1}' | tr '\n' ' '))
    if [[ -n "${Qrequires[@]}" ]]; then
        show_note "f" $"failed to prepare transaction (could not satisfy dependencies)"
        show_note "e" $"${Qrequires[@]}: requires $@"
    fi
}

function ignore_deps_checks() {
    local i
    # global ignoredpkgs aurpkgs aurdepspkgs aurdepspkgsAgrp aurdepspkgsQgrp repodepspkgsSgrp repodepspkgsQgrp rmaurpkgs deps repodepspkgs
    [[ -z "${ignoredpkgs[@]}" && -z "${ignoredgrps[@]}" ]] && return

    # add checked targets and preserve tsorted order
    deps=(${deps[@]:0:${#aurpkgs[@]}})

    # check dependencies
    for i in "${repodepspkgs[@]}"; do
        unset isignored
        if [[ " ${ignoredpkgs[@]} " =~ " $i " ]]; then
            isignored=true
        elif [[ -n "${ignoredgrps[@]}" ]]; then
            unset repodepspkgsSgrp repodepspkgsQgrp
            repodepspkgsSgrp=($(expac -S -1 '%G' "$i"))
            for j in "${repodepspkgsSgrp[@]}"; do
                [[ " ${ignoredgrps[@]} " =~ " $j " ]] && isignored=true
            done
            repodepspkgsQgrp=($(expac -Q '%G' "$i"))
            for j in "${repodepspkgsQgrp[@]}"; do
                [[ " ${ignoredgrps[@]} " =~ " $j " ]] && isignored=true
            done
        fi

        if [[ $isignored = true ]]; then
            if [[ ! $upgrade ]]; then
                show_note "w" $"skipping target: ${colorW}$i${reset}"
            else
                show_note "w" $"${colorW}$i${reset}: ignoring package upgrade"
            fi
            show_note "e" $"Unresolved dependency '${colorW}$i${reset}'"
        fi
    done
    for i in "${aurdepspkgs[@]}"; do
        # skip already checked dependencies
        [[ " ${aurpkgs[@]} " =~ " $i " ]] && continue
        [[ " ${rmaurpkgs[@]} " =~ " $i " ]] && show_note "e" $"Unresolved dependency '${colorW}$i${reset}'"

        unset isignored
        if [[ " ${ignoredpkgs[@]} " =~ " $i " ]]; then
            isignored=true
        elif [[ -n "${ignoredgrps[@]}" ]]; then
            unset aurdepspkgsAgrp aurdepspkgsQgrp
            aurdepspkgsAgrp=($(get_json "arrayvar" "$json" "Groups" "$i"))
            for j in "${aurdepspkgsAgrp[@]}"; do
                [[ " ${ignoredgrps[@]} " =~ " $j " ]] && isignored=true
            done
            aurdepspkgsQgrp=($(expac -Q '%G' "$i"))
            for j in "${aurdepspkgsQgrp[@]}"; do
                [[ " ${ignoredgrps[@]} " =~ " $j " ]] && isignored=true
            done
        fi

        if [[ $isignored = true ]]; then
            if [[ ! $noconfirm ]]; then
                if ! do_proceed "y" $"$i dependency is in IgnorePkg/IgnoreGroup. Install anyway?"; then
                    show_note "w" $"skipping target: ${colorW}$i${reset}"
                    show_note "e" $"Unresolved dependency '${colorW}$i${reset}'"
                fi
            else
                if [[ ! $upgrade ]]; then
                    show_note "w" $"skipping target: ${colorW}$i${reset}"
                else
                    show_note "w" $"${colorW}$i${reset}: ignoring package upgrade"
                fi
                show_note "e" $"Unresolved dependency '${colorW}$i${reset}'"
            fi
        fi
        deps+=($i)
    done
}

function provider_checks() {
    local allproviders providersdeps providers repodepspkgsprovided providerspkgs provided nb providersnb
    # global repodepspkgs repoprovidersconflictingpkgs repodepsSver repodepsSrepo repodepsQver
    [[ -z "${repodepspkgs[@]}" ]] && return

    # filter directly provided deps
    noprovidersdeps=($(expac -S -1 '%n' ${repodepspkgs[@]}))
    providersdeps=($(grep -xvf <(printf '%s\n' "${noprovidersdeps[@]}") <(printf '%s\n' "${repodepspkgs[@]}")))

    # remove installed providers
    providersdeps=($($pacmanbin -T ${providersdeps[@]} | sort -u))

    for i in "${!providersdeps[@]}"; do
        providers=($(expac -Ss '%n' "^${providersdeps[$i]}$" | sort -u))
        [[ ! ${#providers[@]} -gt 1 ]] && continue

        # skip if provided in dependency chain
        unset repodepspkgsprovided
        for j in "${!providers[@]}"; do
            [[ " ${repodepspkgs[@]} " =~ " ${providers[$j]} " ]] && repodepspkgsprovided='true'
        done
        [[ $repodepspkgsprovided ]] && continue

        # skip if already provided
        if [[ -n "${providerspkgs[@]}" ]]; then
            providerspkgs=($(tr ' ' '|' <<< ${providerspkgs[@]}))
            provided+=($(expac -Ss '%S' "^(${providerspkgs[*]})$"))
            [[ " ${provided[@]} " =~ " ${providersdeps[$i]} " ]] && continue
        fi

        if [[ ! $noconfirm ]]; then
            show_note "i" $"${colorW}There are ${#providers[@]} providers available for ${providersdeps[$i]}:${reset}"
            expac -S -1 '   %!) %n (%r) ' "${providers[@]}"

            local nb=-1
            providersnb=$(( ${#providers[@]} -1 )) # count from 0
            while [[ $nb -lt 0 || $nb -ge ${#providers} ]]; do

                printf "\n%s " $"Enter a number (default=0):"
                case "$TERM" in
                    dumb)
                    read -r nb
                    ;;
                    *)
                    read -r -n "$(echo -n $providersnb | wc -m)" nb
                    echo
                    ;;
                esac

                case $nb in
                    [0-9]|[0-9][0-9])
                        if [[ $nb -lt 0 || $nb -ge ${#providers[@]} ]]; then
                            echo && show_note "f" $"invalid value: $nb is not between 0 and $providersnb" && ((i--))
                        else
                            break
                        fi;;
                    '') nb=0;;
                    *) show_note "f" $"invalid number: $nb";;
                esac
            done
        else
            local nb=0
        fi
        providerspkgs+=(${providers[$nb]})
    done

    # add selected providers to repo deps
    repodepspkgs+=(${providerspkgs[@]})

    # store for installation
    repoprovidersconflictingpkgs+=(${providerspkgs[@]})

    find_deps_repo_provider ${providerspkgs[@]}

    # get binary packages info
    if [[ -n "${repodepspkgs[@]}" ]]; then
        repodepspkgs=($(expac -S -1 '%n' "${repodepspkgs[@]}" | LC_COLLATE=C sort -u))
        repodepsSver=($(expac -S -1 '%v' "${repodepspkgs[@]}"))
        repodepsQver=($(expac -Q '%v' "${repodepspkgs[@]}"))
        repodepsSrepo=($(expac -S -1 '%r/%n' "${repodepspkgs[@]}"))
    fi
}

function conflict_checks() {
    local allQprovides allQconflicts Aprovides Aconflicts aurconflicts aurAconflicts Qrequires i j k
    local repodepsprovides repodepsconflicts checkedrepodepsconflicts repodepsconflictsname repodepsconflictsver localver repoconflictingpkgs
    # global deps depsAname json aurdepspkgs aurconflictingpkgs aurconflictingpkgsrm depsQver repodepspkgs repoconflictingpkgsrm repoprovidersconflictingpkgs
    show_note "i" $"looking for inter-conflicts..."

    allQprovides=($(expac -Q '%n'))
    allQprovides+=($(expac -Q '%S')) # no versioning
    allQconflicts=($(expac -Q '%C'))

    # AUR conflicts
    Aprovides=(${depsAname[@]})
    Aprovides+=($(get_json "array" "$json" "Provides"))
    Aconflicts=($(get_json "array" "$json" "Conflicts"))
    # remove AUR versioning
    for i in "${!Aprovides[@]}"; do
        Aprovides[$i]=$(awk -F ">|<|=" '{print $1}' <<< ${Aprovides[$i]})
    done
    for i in "${!Aconflicts[@]}"; do
        Aconflicts[$i]=$(awk -F ">|<|=" '{print $1}' <<< ${Aconflicts[$i]})
    done
    aurconflicts=($(grep -xf <(printf '%s\n' "${Aprovides[@]}") <(printf '%s\n' "${allQconflicts[@]}")))
    aurconflicts+=($(grep -xf <(printf '%s\n' "${Aconflicts[@]}") <(printf '%s\n' "${allQprovides[@]}")))
    aurconflicts=($(tr ' ' '\n' <<< ${aurconflicts[@]} | LC_COLLATE=C sort -u))

    for i in "${aurconflicts[@]}"; do
        unset aurAconflicts
        [[ " ${depsAname[@]} " =~ " $i " ]] && aurAconflicts=($i)
        for j in "${depsAname[@]}"; do
            [[ " $(get_json "arrayvar" "$json" "Conflicts" "$j") " =~ " $i " ]] && aurAconflicts+=($j)
        done

        for j in "${aurAconflicts[@]}"; do
            unset k Aprovides
            k=$(expac -Qs '%n %P' "^$i$" | head -1 | grep -E "([^a-zA-Z0-9_@\.\+-]$i|^$i)" | grep -E "($i[^a-zA-Z0-9\.\+-]|$i$)" | awk '{print $1}')
            [[ ! $installpkg && ! " ${aurdepspkgs[@]} " =~ " $j " ]] && continue # skip if downloading target only
            [[ "$j" == "$k" || -z "$k" ]] && continue # skip if reinstalling or if no conflict exists

            Aprovides=($j)
            if [[ ! $noconfirm && ! " ${aurconflictingpkgs[@]} " =~ " $k " ]]; then
                if ! do_proceed "n" $"$j and $k are in conflict ($i). Remove $k?"; then
                    aurconflictingpkgs+=($j $k)
                    aurconflictingpkgsrm+=($k)
                    for l in "${!depsAname[@]}"; do
                        [[ " ${depsAname[$l]} " =~ "$k" ]] && depsQver[$l]=$(expac -Qs '%v' "^$k$" | head -1)
                    done
                    Aprovides+=($(get_json "arrayvar" "$json" "Provides" "$j"))
                    # remove AUR versioning
                    for l in "${!Aprovides[@]}"; do
                        Aprovides[$l]=$(awk -F ">|<|=" '{print $1}' <<< ${Aprovides[$l]})
                    done
                    [[ ! " ${Aprovides[@]} " =~ " $k " && ! " ${aurconflictingpkgsrm[@]} " =~ " $k " ]] && check_requires $k
                    break
                else
                    show_note "f" $"unresolvable package conflicts detected"
                    show_note "f" $"failed to prepare transaction (conflicting dependencies)"
                    if [[ $upgrade ]]; then
                        Qrequires=($(expac -Q '%N' "$i"))
                        show_note "e" $"$j and $k are in conflict (required by ${Qrequires[*]})"
                    else
                        show_note "e" $"$j and $k are in conflict"
                    fi
                fi
            fi
            Aprovides+=($(get_json "arrayvar" "$json" "Provides" "$j"))
            # remove AUR versioning
            for l in "${!Aprovides[@]}"; do
                Aprovides[$l]=$(awk -F ">|<|=" '{print $1}' <<< ${Aprovides[$l]})
            done
            [[ ! " ${Aprovides[@]} " =~ " $k " && ! " ${aurconflictingpkgsrm[@]} " =~ " $k " ]] && check_requires $k
        done
    done

    nothing_to_do ${deps[@]}

    # repo conflicts
    if [[ -n "${repodepspkgs[@]}" ]]; then
        repodepsprovides=(${repodepspkgs[@]})
        repodepsprovides+=($(expac -S -1 '%S' "${repodepspkgs[@]}")) # no versioning
        repodepsconflicts=($(expac -S -1 '%H' "${repodepspkgs[@]}"))

        # versioning check
        unset checkedrepodepsconflicts
        for i in "${!repodepsconflicts[@]}"; do
            unset repodepsconflictsname repodepsconflictsver localver
            repodepsconflictsname=${repodepsconflicts[$i]} && repodepsconflictsname=${repodepsconflictsname%[><]*} && repodepsconflictsname=${repodepsconflictsname%=*}
            repodepsconflictsver=${repodepsconflicts[$i]} && repodepsconflictsver=${repodepsconflictsver#*=} && repodepsconflictsver=${repodepsconflictsver#*[><]}
            [[ $repodepsconflictsname ]] && localver=$(expac -Q '%v' $repodepsconflictsname)

            if [[ $localver ]]; then
                case "${repodepsconflicts[$i]}" in
                        *">="*) [[ $(vercmp "$repodepsconflictsver" "$localver") -ge 0 ]] && continue;;
                        *"<="*) [[ $(vercmp "$repodepsconflictsver" "$localver") -le 0 ]] && continue;;
                        *">"*)  [[ $(vercmp "$repodepsconflictsver" "$localver") -gt 0 ]] && continue;;
                        *"<"*)  [[ $(vercmp "$repodepsconflictsver" "$localver") -lt 0 ]] && continue;;
                        *"="*)  [[ $(vercmp "$repodepsconflictsver" "$localver") -eq 0 ]] && continue;;
                esac
                checkedrepodepsconflicts+=($repodepsconflictsname)
            fi
        done

        repoconflicts+=($(grep -xf <(printf '%s\n' "${repodepsprovides[@]}") <(printf '%s\n' "${allQconflicts[@]}")))
        repoconflicts+=($(grep -xf <(printf '%s\n' "${checkedrepodepsconflicts[@]}") <(printf '%s\n' "${allQprovides[@]}")))
        repoconflicts=($(tr ' ' '\n' <<< ${repoconflicts[@]} | LC_COLLATE=C sort -u))
    fi

    for i in "${repoconflicts[@]}"; do
        unset Qprovides
        repoSconflicts=($(expac -S -1 '%n %C %S' "${repodepspkgs[@]}" | grep -E "[^a-zA-Z0-9_@\.\+-]$i" | grep -E "($i[^a-zA-Z0-9\.\+-]|$i$)" | awk '{print $1}'))
        for j in "${repoSconflicts[@]}"; do
            unset k && k=$(expac -Qs '%n %P' "^$i$" | head -1 | grep -E "([^a-zA-Z0-9_@\.\+-]$i|^$i)" | grep -E "($i[^a-zA-Z0-9\.\+-]|$i$)" | awk '{print $1}')
            [[ "$j" == "$k" || -z "$k" ]] && continue # skip when no conflict with repopkgs

            if [[ ! $noconfirm && ! " ${repoconflictingpkgs[@]} " =~ " $k " ]]; then
                if ! do_proceed "n" $"$j and $k are in conflict ($i). Remove $k?"; then
                    repoconflictingpkgs+=($j $k)
                    repoconflictingpkgsrm+=($k)
                    repoprovidersconflictingpkgs+=($j)
                    Qprovides=($(expac -Ss '%S' "^$k$"))
                    [[ ! " ${Qprovides[@]} " =~ " $k " && ! " ${repoconflictingpkgsrm[@]} " =~ " $k " ]] && check_requires $k
                    break
                else
                    show_note "f" $"unresolvable package conflicts detected"
                    show_note "f" $"failed to prepare transaction (conflicting dependencies)"
                    if [[ $upgrade ]]; then
                        Qrequires=($(expac -Q '%N' "$i"))
                        show_note "e" $"$j and $k are in conflict (required by ${Qrequires[*]})"
                    else
                        show_note "e" $"$j and $k are in conflict"
                    fi
                fi
            fi
            Qprovides=($(expac -Ss '%S' "^$k$"))
            [[ ! " ${Qprovides[@]} " =~ " $k " ]] && check_requires $k
        done
    done
}

function reinstall_checks() {
    local i depsAtmp
    # global aurpkgs aurdepspkgs deps aurconflictingpkgs depsAname depsQver depsAver depsAood depsAmain
    depsAtmp=(${depsAname[@]})
    for i in "${!depsAtmp[@]}"; do
        [[ ! $foreign ]] && [[ ! " ${aurpkgs[@]} " =~ " ${depsAname[$i]} " || " ${aurconflictingpkgs[@]} " =~ " ${depsAname[$i]} " ]] && continue
        [[ -z "${depsQver[$i]}" || "${depsQver[$i]}" = '#' || $(vercmp "${depsAver[$i]}" "${depsQver[$i]}") -gt 0 ]] && continue
        [[ ! $installpkg && ! " ${aurdepspkgs[@]} " =~ " ${depsAname[$i]} " ]] && continue
        if [[ -n "$(grep -E "\-(cvs|svn|git|hg|bzr|darcs|daily.*|nightly.*)$" <<< ${depsAname[$i]})" ]]; then
            show_note "w" $"${colorW}${depsAname[$i]}${reset} latest revision -- fetching"
        else
            if [[ ! $needed ]]; then
                show_note "w" $"${colorW}${depsAname[$i]}-${depsQver[$i]}${reset} is up to date -- reinstalling"
            else
                show_note "w" $"${colorW}${depsAname[$i]}-${depsQver[$i]}${reset} is up to date -- skipping"
                deps=($(tr ' ' '\n' <<< ${deps[@]} | sed "s/^${depsAname[$i]}$//g"))
                unset depsAname[$i] depsQver[$i] depsAver[$i] depsAood[$i] depsAmain[$i]
            fi
        fi
    done
    [[ $needed ]] && depsAname=(${depsAname[@]}) && depsQver=(${depsQver[@]}) && depsAver=(${depsAver[@]}) && depsAood=(${depsAood[@]}) && depsAmain=(${depsAmain[@]})

    nothing_to_do ${deps[@]}
}

function outofdate_checks() {
    local i
    # global depsAname depsAver depsAood
    for i in "${!depsAname[@]}"; do
        [[ "${depsAood[$i]}" -gt 0 ]] && show_note "w" $"${colorW}${depsAname[$i]}-${depsAver[$i]}${reset} has been flagged ${colorR}out of date${reset} on ${colorY}$(date -d "@${depsAood[$i]}" "+%c")${reset}"
    done
}

function orphan_checks() {
    local i
    # global depsAname depsAver depsAmain
    for i in "${!depsAname[@]}"; do
      [[ "${depsAmain[$i]}" == 'null' ]] && show_note "w" $"${colorW}${depsAname[$i]}-${depsAver[$i]}${reset} is ${colorR}orphaned${reset} in AUR"
    done
}

# vim:set ts=4 sw=2 et:
