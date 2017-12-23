#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

do_core() {
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

# only used in do_core
do_prompt() {
    local i binaryksize sumk summ builtpkg cachedpkgs strname stroldver strnewver strsize action
    local depsver repodepspkgsver strrepodlsize strrepoinsize strsumk strsumm lreposizelabel lreposize
    # global repodepspkgs repodepsSver depsAname depsAver depsArepo depsAcached lname lver lsize deps depsQver repodepspkgs repodepsSrepo repodepsQver repodepsSver
    # compute binary size
    if [[ -n "${repodepspkgs[@]}" ]]; then
        binaryksize=($(expac -S -1 '%k' "${repodepspkgs[@]}"))
        binarymsize=($(expac -S -1 '%m' "${repodepspkgs[@]}"))
        sumk=0
        summ=0
        for i in "${!repodepspkgs[@]}"; do
            GetBuiltPkg "${repodepspkgs[$i]}-${repodepsSver[$i]}" '/var/cache/pacman/pkg'
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
        GetBuiltPkg "${depsAname[$i]}-${depsAver[$i]}" "$PKGDEST"
        [[ $builtpkg ]] && cachedpkgs+=(${depsAname[$i]}) && depsAcached[$i]=$"(cached)" || depsAcached[$i]=""
        unset builtpkg
    done

    if [[ -n "$(grep '^VerbosePkgLists' '/etc/pacman.conf')" ]]; then
        straurname=$"AUR Packages  (${#deps[@]})"; strreponame=$"Repo Packages (${#repodepspkgs[@]})"; stroldver=$"Old Version"; strnewver=$"New Version"; strsize=$"Download Size"
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
    else
        # show version
        for i in "${!deps[@]}"; do
            depsver="${depsver}${depsAname[$i]}-${depsAver[$i]}  "
        done
        for i in "${!repodepspkgs[@]}"; do
            repodepspkgsver="${repodepspkgsver}${repodepspkgs[$i]}-${repodepsSver[$i]}  "
        done
        printf "\n${colorW}%-16s${reset} %s\n" $"AUR Packages  (${#deps[@]})" "$depsver"
        [[ -n "${repodepspkgs[@]}" ]] && printf "${colorW}%-16s${reset} %s\n" $"Repo Packages (${#repodepspkgs[@]})" "$repodepspkgsver"
    fi

    if [[ -n "${repodepspkgs[@]}" ]]; then
        strrepodlsize=$"Repo Download Size:"; strrepoinsize=$"Repo Installed Size:"; strsumk=$"$sumk MiB"; strsumm=$"$summ MiB"
        lreposizelabel=$(helper_get_length "$strrepodlsize" "$strrepoinsize")
        lreposize=$(helper_get_length "$strsumk" "$strsumm")
        printf "\n${colorW}%-${lreposizelabel}s${reset}  %${lreposize}s\n" "$strrepodlsize" "$strsumk"
        printf "${colorW}%-${lreposizelabel}s${reset}  %${lreposize}s\n" "$strrepoinsize" "$strsumm"
    fi

    echo
    [[ $installpkg ]] && action=$"installation" || action=$"download"
    if ! do_proceed "y" $"Proceed with $action?"; then
        exit
    fi
}

# only used in do_core
upgrade_aur() {
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


# vim:set ts=4 sw=2 et:
