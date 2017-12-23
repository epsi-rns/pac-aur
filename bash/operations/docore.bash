#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

do_core() {
    # buildonly, upgrade: option handling

    get_ignored_pkgs
    get_ignored_grps
    [[ $upgrade ]] && upgrade_aur
    ignore_checks
    deps_solver
    ignore_deps_checks
    provider_checks
    conflict_checks
    reinstall_checks
    outofdate_checks
    orphan_checks
    do_prompt
    make_pkgs
}

function _show_repo_deps_pkgs() {
    local sumk=$1
    local summ=$2
    
    local strrepodlsize strrepoinsize strsumk strsumm lreposizelabel lreposize

    strrepodlsize=$"Repo Download Size:"; 
    strrepoinsize=$"Repo Installed Size:"; 
    strsumk=$"$sumk MiB"; 
    strsumm=$"$summ MiB"
    lreposizelabel=$(helper_get_length "$strrepodlsize" "$strrepoinsize")
    lreposize=$(helper_get_length "$strsumk" "$strsumm")
    printf "\n${colorW}%-${lreposizelabel}s${reset}  %${lreposize}s\n" "$strrepodlsize" "$strsumk"
    printf "${colorW}%-${lreposizelabel}s${reset}  %${lreposize}s\n" "$strrepoinsize" "$strsumm"
}

function _show_pkg_lists_verbose() {
    local strname stroldver strnewver strsize

    straurname=$"AUR Packages  (${#deps[@]})"
    strreponame=$"Repo Packages (${#repodepspkgs[@]})"
    stroldver=$"Old Version" 
    strnewver=$"New Version" 
    strsize=$"Download Size"

    depsArepo=(${depsAname[@]/#/aur/})
    lname=$(helper_get_length ${depsArepo[@]} ${repodepsSrepo[@]} "$straurname" "$strreponame")
    lver=$(helper_get_length ${depsQver[@]} ${depsAver[@]} ${repodepsQver[@]} ${repodepsSver[@]} "$stroldver" "$strnewver")
    lsize=$(helper_get_length "$strsize")

    # local version column cleanup
    for i in "${!deps[@]}"; do
        [[ "${depsQver[$i]}" =~ '#' ]] && unset depsQver[$i]
    done
    # show detailed output
    printf "\n${colorW}%-${lname}s  %-${lver}s  %-${lver}s${reset}\n\n" "$straurname" "$stroldver" "$strnewver"
    for i in "${!deps[@]}"; do
        printf "%-${lname}s  ${colorR}%-${lver}s${reset}  ${colorG}%-${lver}s${reset}  %${lsize}s\n" "${depsArepo[$i]}" "${depsQver[$i]}" "${depsAver[$i]}" "${depsAcached[$i]}";
    done

    if [[ -n "${repodepspkgs[@]}" ]]; then
        for i in "${!repodepspkgs[@]}"; do
            binarysize[$i]=$(awk '{ printf("%.2f\n", $1/$2) }' <<< "${binaryksize[$i]} 1048576")
        done
        printf "\n${colorW}%-${lname}s  %-${lver}s  %-${lver}s  %s${reset}\n\n" "$strreponame" "$stroldver" "$strnewver" "$strsize"
        for i in "${!repodepspkgs[@]}"; do
            printf "%-${lname}s  ${colorR}%-${lver}s${reset}  ${colorG}%-${lver}s${reset}  %${lsize}s\n" "${repodepsSrepo[$i]}" "${repodepsQver[$i]}" "${repodepsSver[$i]}" $"${binarysize[$i]} MiB";
        done
    fi
}

function _show_pkg_lists_default() {
    local depsver repodepspkgsver 

    # show version
    for i in "${!deps[@]}"; do
        depsver="${depsver}${depsAname[$i]}-${depsAver[$i]}  "
    done
    for i in "${!repodepspkgs[@]}"; do
        repodepspkgsver="${repodepspkgsver}${repodepspkgs[$i]}-${repodepsSver[$i]}  "
    done
    printf "\n${colorW}%-16s${reset} %s\n" $"AUR Packages  (${#deps[@]})" "$depsver"
    [[ -n "${repodepspkgs[@]}" ]] && printf "${colorW}%-16s${reset} %s\n" $"Repo Packages (${#repodepspkgs[@]})" "$repodepspkgsver"
}

# only used in do_core
function do_prompt() {
    local i binaryksize sumk summ builtpkg cachedpkgs action

    # global repodepspkgs repodepsSver depsAname depsAver depsArepo depsAcached lname lver lsize deps depsQver repodepspkgs repodepsSrepo repodepsQver repodepsSver
    # compute binary size
    # -n : string is not null.
    if [[ -n "${repodepspkgs[@]}" ]]; then   
        # %k    download size
        binaryksize=($(expac -S -1 '%k' "${repodepspkgs[@]}"))
        # %m    install size
        binarymsize=($(expac -S -1 '%m' "${repodepspkgs[@]}"))
        sumk=0
        summ=0
        for i in "${!repodepspkgs[@]}"; do
            get_built_pkg "${repodepspkgs[$i]}-${repodepsSver[$i]}" '/var/cache/pacman/pkg'
            [[ $builtpkg ]] && binaryksize[$i]=0
            sumk=$((sumk + ${binaryksize[$i]}))
            summ=$((summ + ${binarymsize[$i]}))
        done
        sumk=$(awk '{ printf("%.2f\n", $1/$2) }' <<< "$sumk 1048576")
        summ=$(awk '{ printf("%.2f\n", $1/$2) }' <<< "$summ 1048576")
    fi

    # cached packages check
    for i in "${!depsAname[@]}"; do    

        [[ ! $PKGDEST || $rebuild ]] && break
        get_built_pkg "${depsAname[$i]}-${depsAver[$i]}" "$PKGDEST"
        [[ $builtpkg ]] && cachedpkgs+=(${depsAname[$i]}) && depsAcached[$i]=$"(cached)" || depsAcached[$i]=""
        unset builtpkg
    done

    if [[ -n "$(grep '^VerbosePkgLists' '/etc/pacman.conf')" ]]; then       
        _show_pkg_lists_verbose
    else
        _show_pkg_lists_default
    fi

    if [[ -n "${repodepspkgs[@]}" ]]; then
        _show_repo_deps_pkgs $sumk $summ
    fi

    echo
    [[ $installpkg ]] && action=$"installation" || action=$"download"
    if ! do_proceed "y" $"Proceed with $action?"; then
        exit
    fi
}

# only used in do_core
function upgrade_aur() {
    local foreignpkgs allaurpkgs allaurpkgsAver allaurpkgsQver aurforeignpkgs i json
    # global aurpkgs
    show_note "i" $"${colorW}Starting AUR upgrade...${reset}"

    # selective upgrade switch
    if [[ $selective && -n ${pkgs[@]} ]]; then
        aurpkgs+=(${pkgs[@]})
    else
        foreignpkgs=($($pacmanbin -Qmq))
        set_json ${foreignpkgs[@]}
        allaurpkgs=($(get_json "var" "$json" "Name"))
        allaurpkgsAver=($(get_json "var" "$json" "Version"))
        allaurpkgsQver=($(expac -Q '%v' ${allaurpkgs[@]}))
        for i in "${!allaurpkgs[@]}"; do
            [[ $(vercmp "${allaurpkgsAver[$i]}" "${allaurpkgsQver[$i]}") -gt 0 ]] && aurpkgs+=(${allaurpkgs[$i]});
        done
    fi

    # foreign packages check
    aurforeignpkgs=($(grep -xvf <(printf '%s\n' "${allaurpkgs[@]}") <(printf '%s\n' "${foreignpkgs[@]}")))
    for i in "${aurforeignpkgs[@]}"; do
        show_note "w" $"${colorW}$i${reset} is ${colorY}not present${reset} in AUR -- skipping"
    done

    # add devel packages
    if [[ $devel ]]; then
        for i in "${allaurpkgs[@]}"; do
            [[ -n "$(grep -E "\-(cvs|svn|git|hg|bzr|darcs|daily.*|nightly.*)$" <<< $i)" ]] && aurpkgs+=($i)
        done
    fi

    # avoid possible duplicate
    aurpkgs=($(tr ' ' '\n' <<< ${aurpkgs[@]} | sort -u))

    nothing_to_do ${aurpkgs[@]}
}

# only used in do_core
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
