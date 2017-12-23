#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

function deps_solver() {
    local i aurpkgsname aurpkgsver aurpkgsaurver aurpkgsconflicts
    # global aurpkgs aurpkgsnover aurpkgsproviders aurdeps deps json errdeps errdepsnover foreignpkgs repodeps depsAname depsAver depsAood depsQver
    show_note "i" $"resolving dependencies..."

    # remove AUR pkgs versioning
    for i in "${!aurpkgs[@]}"; do
        aurpkgsnover[$i]=$(awk -F ">|<|=" '{print $1}' <<< ${aurpkgs[$i]})
    done

    # set unversionned json
    set_json ${aurpkgsnover[@]}

    # set targets providers
    aurpkgsproviders=(${aurpkgsnover[@]})
    aurpkgsproviders+=($(get_json "array" "$json" "Provides"))
    for i in "${!aurpkgsproviders[@]}"; do
        aurpkgsproviders[$i]=$(awk -F ">|<|=" '{print $1}' <<< ${aurpkgsproviders[$i]})
    done

    # check targets conflicts
    aurpkgsconflicts=($(get_json "array" "$json" "Conflicts"))
    if [[ -n "${aurpkgsconflicts[@]}" ]]; then
        for i in "${!aurpkgsconflicts[@]}"; do
            aurpkgsconflicts[$i]=$(awk -F ">|<|=" '{print $1}' <<< ${aurpkgsconflicts[$i]})
        done

        aurpkgsconflicts=($(grep -xf <(printf '%s\n' "${aurpkgsproviders[@]}") <(printf '%s\n' "${aurpkgsconflicts[@]}")))
        aurpkgsconflicts=($(tr ' ' '\n' <<< ${aurpkgsconflicts[@]} | LC_COLLATE=C sort -u))

        for i in "${aurpkgsconflicts[@]}"; do
            [[ ! " ${aurpkgsnover[@]} " =~ " $i " ]] && continue
            [[ " $(get_json "arrayvar" "$json" "Conflicts" "$i") " =~ " $i " ]] && continue
            show_note "f" $"unresolvable package conflicts detected"
            show_note "e" $"failed to prepare transaction (conflicting dependencies: $i)"
        done
    fi

    deps=(${aurpkgsnover[@]})

    [[ -z "${foreignpkgs[@]}" ]] && foreignpkgs=($($pacmanbin -Qmq))
    find_deps_aur ${aurpkgsnover[@]}

    # avoid possible duplicate
    deps=($(grep -xvf <(printf '%s\n' "${aurdepspkgs[@]}") <(printf '%s\n' "${deps[@]}")))
    deps+=(${aurdepspkgs[@]})

    # ensure correct dependency order
    set_json ${deps[@]}
    sort_deps_aur ${aurpkgs[@]}
    deps=($(tsort <<< ${tsortdeps[@]}))

    # error check
    if (($? > 0)); then
        show_note "e" $"dependency cycle detected"
    fi

    # get AUR packages info
    depsAname=($(get_json "var" "$json" "Name"))
    depsAver=($(get_json "var" "$json" "Version"))
    depsAood=($(get_json "var" "$json" "OutOfDate"))
    depsAmain=($(get_json "var" "$json" "Maintainer"))
    for i in "${!depsAname[@]}"; do
        depsQver[$i]=$(expac -Qs '%v' "^${depsAname[$i]}$" | head -1)
        [[ -z "${depsQver[$i]}" ]] && depsQver[$i]="#"  # avoid empty elements shift
        [[ -n "$(grep -E "\-(cvs|svn|git|hg|bzr|darcs|daily.*|nightly.*)$" <<< ${depsAname[$i]})" ]] && depsAver[$i]=$"latest"
    done

    # no results check
    if [[ -n "${errdeps[@]}" ]]; then
        for i in "${!errdepsnover[@]}"; do
            if [[ " ${aurpkgsnover[@]} " =~ " ${errdepsnover[$i]} " ]]; then
                show_note "f" $"no results found for ${errdeps[$i]}"
            else
                unset tsorterrdeps errdepslist currenterrdep
                # find relevant tsorted deps chain
                for j in "${deps[@]}"; do
                    tsorterrdeps+=($j)
                    [[ " $j " = " ${errdepsnover[$i]} " ]] && break
                done
                # reverse deps order
                tsorterrdeps=($(awk '{for (i=NF;i>=1;i--) print $i}' <<< ${tsorterrdeps[@]} | awk -F "\n" '{print}'))
                errdepslist+=(${tsorterrdeps[0]})
                FindDepsAurError ${tsorterrdeps[@]}
                errdepslist=($(awk '{for (i=NF;i>=1;i--) print $i}' <<< ${errdepslist[@]} | awk -F "\n" '{print}'))
                show_note "f" $"no results found for ${errdeps[$i]} (dependency tree: ${errdepslist[*]})"
            fi
        done
        exit 1
    fi

    # return all binary deps
    find_deps_repo ${repodeps[@]}

    # avoid possible duplicate
    repodepspkgs=($(tr ' ' '\n' <<< ${repodepspkgs[@]} | sort -u))
}

function find_deps_aur() {
    local depspkgs depspkgstmp depspkgsaurtmp repodepstmp builtpkg vcsdepspkgs assumedepspkgs
    local aurversionpkgs aurversionpkgsname aurversionpkgsver aurversionpkgsaurver i j json
    # global aurpkgsnover depspkgsaur errdeps depsAname depsAver repodeps aurdepspkgs prevdepspkgsaur foreignpkgs
    [[ $nodeps && $count -ge 2 ]] && return

    # set json
    unset aurversionpkgs
    if [[ -z "${depspkgsaur[@]}" ]]; then
        set_json ${aurpkgsnover[@]}
        aurversionpkgs=(${aurpkgs[@]})
    else
        set_json ${depspkgsaur[@]}
        aurversionpkgs=(${prevdepspkgsaur[@]})
    fi

    # versioning check
    if [[ -n "${aurversionpkgs[@]}" ]]; then
        for i in "${!aurversionpkgs[@]}"; do
            unset aurversionpkgsname aurversionpkgsver aurversionpkgsaurver
            aurversionpkgsname=${aurversionpkgs[$i]} && aurversionpkgsname=${aurversionpkgsname%[><]*} && aurversionpkgsname=${aurversionpkgsname%=*}
            aurversionpkgsver=${aurversionpkgs[$i]} && aurversionpkgsver=${aurversionpkgsver#*=} && aurversionpkgsver=${aurversionpkgsver#*[><]}
            aurversionpkgsaurver=$(get_json "varvar" "$json" "Version" "$aurversionpkgsname")

            # not found in AUR nor repo
            if [[ ! $aurversionpkgsaurver ]]; then
                [[ ! " ${errdeps[@]} " =~ " ${aurversionpkgs[$i]} " ]] && errdeps+=(${aurversionpkgs[$i]})
                continue
            fi

            case "${aurversionpkgs[$i]}" in
                *">"*|*"<"*|*"="*)
                    # found in AUR but version not correct
                    case "${aurversionpkgs[$i]}" in
                        *">="*) [[ $(vercmp "$aurversionpkgsaurver" "$aurversionpkgsver") -ge 0 ]] && continue;;
                        *"<="*) [[ $(vercmp "$aurversionpkgsaurver" "$aurversionpkgsver") -le 0 ]] && continue;;
                        *">"*)  [[ $(vercmp "$aurversionpkgsaurver" "$aurversionpkgsver") -gt 0 ]] && continue;;
                        *"<"*)  [[ $(vercmp "$aurversionpkgsaurver" "$aurversionpkgsver") -lt 0 ]] && continue;;
                        *"="*)  [[ $(vercmp "$aurversionpkgsaurver" "$aurversionpkgsver") -eq 0 ]] && continue;;
                    esac
                    [[ ! " ${errdeps[@]} " =~ " ${aurversionpkgs[$i]} " ]] && errdeps+=(${aurversionpkgs[$i]})
                ;;
                *) continue;;
            esac
        done
    fi

    depspkgs=($(get_json "array" "$json" "Depends"))

    # cached packages makedeps check
    if [[ ! $PKGDEST || $rebuild || $foreign ]]; then
        depspkgs+=($(get_json "array" "$json" "MakeDepends"))
        depspkgs+=($(get_json "array" "$json" "CheckDepends"))
    else
        [[ -z "${depspkgsaur[@]}" ]] && depspkgsaurtmp=(${aurpkgs[@]}) || depspkgsaurtmp=(${depspkgsaur[@]})
        for i in "${!depspkgsaurtmp[@]}"; do
            depsAname=$(get_json "varvar" "$json" "Name" "${depspkgsaurtmp[$i]}")
            depsAver=$(get_json "varvar" "$json" "Version" "${depspkgsaurtmp[$i]}")
            get_built_pkg "$depsAname-$depsAver" "$PKGDEST"
            if [[ ! $builtpkg ]]; then
                depspkgs+=($(get_json "arrayvar" "$json" "MakeDepends" "${depspkgsaurtmp[$i]}"))
                depspkgs+=($(get_json "arrayvar" "$json" "CheckDepends" "${depspkgsaurtmp[$i]}"))
            fi
            unset builtpkg
        done
    fi

    # remove deps provided by targets
    if [[ -n "${aurpkgsproviders[@]}" ]]; then
        depspkgs=($(grep -xvf <(printf '%s\n' "${aurpkgsproviders[@]}") <(printf '%s\n' "${depspkgs[@]}")))
    fi

    # workaround for limited RPC support of architecture dependent fields
    if [[ ${CARCH} == 'i686' ]]; then
        depspkgstmp=(${depspkgs[@]})
        for i in "${!depspkgstmp[@]}"; do
             [[ -n "$(grep -E "^lib32\-" <<< ${depspkgstmp[$i]})" ]] && depspkgs=($(tr ' ' '\n' <<< ${depspkgs[@]} | sed "s/^${depspkgstmp[$i]}$//g"))
             [[ -n "$(grep -E "^gcc-multilib$" <<< ${depspkgstmp[$i]})" ]] && depspkgs=($(tr ' ' '\n' <<< ${depspkgs[@]} | sed "s/^${depspkgstmp[$i]}$//g"))
        done
    fi

    # remove installed deps
    if [[ ! $foreign && ! $devel ]]; then
        depspkgs=($($pacmanbin -T ${depspkgs[@]} | sort -u))
    else
        # remove versioning and check providers
        unset vcsdepspkgs
        for i in "${!depspkgs[@]}"; do
            depspkgs[$i]=$(awk -F ">|<|=" '{print $1}' <<< ${depspkgs[$i]})
            unset j && j=$(expac -Qs '%n %P' "^${depspkgs[$i]}$" | head -1 | grep -E "([^a-zA-Z0-9_@\.\+-]${depspkgs[$i]}|^${depspkgs[$i]})" | grep -E "(${depspkgs[$i]}[^a-zA-Z0-9\.\+-]|${depspkgs[$i]}$)" | awk '{print $1}')
            if [[ -n "$j" ]]; then
                depspkgs[$i]="$j"
                [[ $devel ]] && [[ ! " ${ignoredpkgs[@]} " =~ " $j " ]] && [[ -n "$(grep -E "\-(cvs|svn|git|hg|bzr|darcs|daily.*|nightly.*)$" <<< $j)" ]] && vcsdepspkgs+=($j)
            else
                foreignpkgs+=(${depspkgs[$i]})
            fi
        done
        # reorder devel
        if [[ $devel ]]; then
            [[ ! $foreign ]] && depspkgs=($($pacmanbin -T ${depspkgs[@]} | sort -u))
            depspkgstmp=($(grep -xvf <(printf '%s\n' "${depspkgs[@]}") <(printf '%s\n' "${vcsdepspkgs[@]}")))
            depspkgstmp+=($(grep -xvf <(printf '%s\n' "${vcsdepspkgs[@]}") <(printf '%s\n' "${depspkgs[@]}")))
            depspkgs=($(tr ' ' '\n' <<< ${depspkgstmp[@]} | LC_COLLATE=C sort -u))
        fi
        # remove installed binary packages only
        if [[ $foreign ]]; then
            depspkgs=($(grep -xf <(printf '%s\n' "${depspkgs[@]}") <(printf '%s\n' "${foreignpkgs[@]}")))
        fi
    fi

    # split binary and AUR depends pkgs
    unset depspkgsaur
    if [[ -n "${depspkgs[@]}" ]]; then
        # remove all pkgs versioning
        if [[ $nodeps && $count -eq 1 ]]; then
            for i in "${!depspkgs[@]}"; do
                depspkgs[$i]=$(awk -F ">|<|=" '{print $1}' <<< ${depspkgs[$i]})
            done
        # assume installed deps
        elif [[ -n "${assumeinstalled[@]}" ]]; then
            # remove versioning
            for i in "${!assumeinstalled[@]}"; do
                unset assumedepspkgs
                assumeinstalled[$i]=$(awk -F ">|<|=" '{print $1}' <<< ${assumeinstalled[$i]})
                for j in "${!depspkgs[@]}"; do
                    assumedepspkgs[$j]=$(awk -F ">|<|=" '{print $1}' <<< ${depspkgs[$j]})
                    [[ " ${assumedepspkgs[@]} " =~ " ${assumeinstalled[$i]} " ]] && depspkgs[$j]=${assumeinstalled[$i]};
                done
            done
            depspkgs=($(grep -xvf <(printf '%s\n' "${assumeinstalled[@]}") <(printf '%s\n' "${depspkgs[@]}")))
        fi
        if [[ -n "${depspkgs[@]}" ]]; then
            depspkgsaur=($(LANG=C $pacmanbin -Sp ${depspkgs[@]} 2>&1 >/dev/null | awk '{print $NF}'))
            repodeps+=($(grep -xvf <(printf '%s\n' "${depspkgsaur[@]}") <(printf '%s\n' "${depspkgs[@]}")))
        fi
    fi
    unset depspkgs

    # remove duplicate
    if [[ -n "${depspkgsaur[@]}" ]]; then
        depspkgsaur=($(grep -xvf <(printf '%s\n' "${aurdepspkgs[@]}") <(printf '%s\n' "${depspkgsaur[@]}")))
    fi

    # dependency cycle check
    [[ -n "${prevdepspkgsaur[@]}" ]] && [[ "${prevdepspkgsaur[*]}" == "${depspkgsaur[*]}" ]] && show_note "e" $"dependency cycle detected (${depspkgsaur[*]})"

    if [[ -n "${depspkgsaur[@]}" ]]; then
        # store for AUR version check
        [[ ! $nodeps ]] && prevdepspkgsaur=(${depspkgsaur[@]})

        # remove AUR pkgs versioning
        for i in "${!depspkgsaur[@]}"; do
            depspkgsaur[$i]=$(awk -F ">|<|=" '{print $1}' <<< ${depspkgsaur[$i]})
        done

        # remove duplicate
        depspkgsaur=($(tr ' ' '\n' <<< ${depspkgsaur[@]} | sort -u))
    fi

    if [[ -n "${depspkgsaur[@]}" ]]; then
        aurdepspkgs+=(${depspkgsaur[@]})
        find_deps_aur ${depspkgsaur[@]}
    fi
}

function sort_deps_aur() {
    local i j sortaurpkgs sortdepspkgs sortdepspkgsaur
    # global checkedsortdepspkgsaur allcheckedsortdepspkgsaur json errdepsnover
    [[ -z "${checkedsortdepspkgsaur[@]}" ]] && sortaurpkgs=(${aurpkgs[@]}) || sortaurpkgs=(${checkedsortdepspkgsaur[@]})

    unset checkedsortdepspkgsaur
    for i in "${!sortaurpkgs[@]}"; do
        unset sortdepspkgs sortdepspkgsaur

        sortdepspkgs+=($(get_json "arrayvar" "$json" "Depends" "${sortaurpkgs[$i]}"))
        sortdepspkgs+=($(get_json "arrayvar" "$json" "MakeDepends" "${sortaurpkgs[$i]}"))
        sortdepspkgs+=($(get_json "arrayvar" "$json" "CheckDepends" "${sortaurpkgs[$i]}"))

        # remove versioning
        for j in "${!errdeps[@]}"; do
            errdepsnover[$j]=$(awk -F ">|<|=" '{print $1}' <<< ${errdeps[$j]})
        done

        # check AUR deps only
        for j in "${!sortdepspkgs[@]}"; do
            sortdepspkgs[$j]=$(awk -F ">|<|=" '{print $1}' <<< ${sortdepspkgs[$j]})
            sortdepspkgsaur+=($(get_json "varvar" "$json" "Name" "${sortdepspkgs[$j]}"))
            # add erroneous AUR deps
            [[ " ${errdepsnover[@]} " =~ " ${sortdepspkgs[$j]} " ]] && sortdepspkgsaur+=("${sortdepspkgs[$j]}")
        done

        # prepare tsort list
        if [[ -z "${sortdepspkgsaur[@]}" ]]; then
            tsortdeps+=("${sortaurpkgs[$i]} ${sortaurpkgs[$i]}")
        else
            for j in "${!sortdepspkgsaur[@]}"; do
                tsortdeps+=("${sortaurpkgs[$i]} ${sortdepspkgsaur[$j]}")
            done
        fi

        # filter non checked deps
        sortdepspkgsaur=($(grep -xvf <(printf '%s\n' "${allcheckedsortdepspkgsaur[@]}") <(printf '%s\n' "${sortdepspkgsaur[@]}")))
        if [[ -n "${sortdepspkgsaur[@]}" ]]; then
            checkedsortdepspkgsaur+=(${sortdepspkgsaur[@]})
            allcheckedsortdepspkgsaur+=(${sortdepspkgsaur[@]})
            allcheckedsortdepspkgsaur=($(tr ' ' '\n' <<< ${allcheckedsortdepspkgsaur[@]} | sort -u))
        fi
    done
    if [[ -n "${checkedsortdepspkgsaur[@]}" ]]; then
        checkedsortdepspkgsaur=($(tr ' ' '\n' <<< ${checkedsortdepspkgsaur[@]} | sort -u))
        sort_deps_aur ${checkedsortdepspkgsaur[@]}
    fi
}

function find_deps_aur_error() {
    local i nexterrdep nextallerrdeps
    # global errdepsnover errdepslist tsorterrdeps currenterrdep

    for i in "${tsorterrdeps[@]}"; do
        [[ ! " ${errdepsnover[@]} " =~ " $i " ]] && [[ ! " ${errdepslist[@]} " =~ " $i " ]] && nexterrdep="$i" && break
    done

    [[ -z "${currenterrdep[@]}" ]] && currenterrdep=${tsorterrdeps[0]}

    if [[ ! " ${aurpkgs[@]} " =~ " $nexterrdep " ]]; then
        nextallerrdeps=($(get_json "arrayvar" "$json" "Depends" "$nexterrdep"))
        nextallerrdeps+=($(get_json "arrayvar" "$json" "MakeDepends" "$nexterrdep"))
        nextallerrdeps+=($(get_json "arrayvar" "$json" "CheckDepends" "$nexterrdep"))

        # remove versioning
        for i in "${!nextallerrdeps[@]}"; do
            nextallerrdeps[$i]=$(awk -F ">|<|=" '{print $1}' <<< ${nextallerrdeps[$i]})
        done

        if [[ " ${nextallerrdeps[@]} " =~ " $currenterrdep " ]]; then
            errdepslist+=("$nexterrdep")
            currenterrdep=${tsorterrdeps[0]}
        fi
        tsorterrdeps=(${tsorterrdeps[@]:1})
        FindDepsAurError ${tsorterrdeps[@]}
    else
        for i in "${!aurpkgs[@]}"; do
            nextallerrdeps=($(get_json "arrayvar" "$json" "Depends" "${aurpkgs[$i]}"))
            nextallerrdeps+=($(get_json "arrayvar" "$json" "MakeDepends" "${aurpkgs[$i]}"))
            nextallerrdeps+=($(get_json "arrayvar" "$json" "CheckDepends" "${aurpkgs[$i]}"))

            # remove versioning
            for j in "${!nextallerrdeps[@]}"; do
                nextallerrdeps[$j]=$(awk -F ">|<|=" '{print $1}' <<< ${nextallerrdeps[$j]})
            done

            if [[ " ${nextallerrdeps[@]} " =~ " $currenterrdep " ]]; then
                errdepslist+=("${aurpkgs[$i]}")
            fi
        done
    fi
}

function find_deps_repo() {
    local allrepodepspkgs repodepspkgstmp
    # global repodeps repodepspkgs
    [[ -z "${repodeps[@]}" ]] && return

    # reduce root binary deps
    repodeps=($(tr ' ' '\n' <<< ${repodeps[@]} | sort -u))

    # add initial repodeps
    [[ -z "${repodepspkgs[@]}" ]] && repodepspkgs=(${repodeps[@]})

    # get non installed repo deps
    allrepodepspkgs=($(expac -S -1 '%E' ${repodeps[@]})) # no version check needed as all deps are binary
    [[ -n "${allrepodepspkgs[@]}" ]] && repodepspkgstmp=($($pacmanbin -T ${allrepodepspkgs[@]} | sort -u))

    if [[ -n "${repodepspkgstmp[@]}" ]]; then
        repodepspkgs+=(${repodepspkgstmp[@]})

        repodeps=(${repodepspkgstmp[@]})
        find_deps_repo ${repodeps[@]}
    fi
}

function find_deps_repo_provider() {
    local allrepodepspkgs providerrepodepspkgstmp
    # global repodeps repodepspkgs
    [[ -z "${providerspkgs[@]}" ]] && return

    # reduce root binary deps
    providerspkgs=($(tr ' ' '\n' <<< ${providerspkgs[@]} | sort -u))

    # add initial repodeps
    [[ -z "${providerspkgspkgs[@]}" ]] && providerspkgspkgs=(${providerspkgs[@]})

    # get non installed repo deps
    allproviderrepodepspkgs=($(expac -S -1 '%E' ${providerspkgs[@]})) # no version check needed as all deps are binary
    [[ -n "${allproviderrepodepspkgs[@]}" ]] && providerrepodepspkgstmp=($($pacmanbin -T ${allproviderrepodepspkgs[@]} | sort -u))

    if [[ -n "${providerrepodepspkgstmp[@]}" ]]; then
        repodepspkgs+=(${providerrepodepspkgstmp[@]})

        providerspkgs=(${providerrepodepspkgstmp[@]})
        find_deps_repo_provider ${providerspkgs[@]}
    fi
}

# vim:set ts=4 sw=2 et:
