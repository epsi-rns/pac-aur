#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

function sudo_v() {
    touch "$tmpdir/pacaur.sudov.lck"
    while [[ -e "$tmpdir/pacaur.sudov.lck" ]]; do
        sudo $pacmanbin -V > /dev/null
        sleep 2
    done
}

function download_pkgs() {
    local i errgit
    # global basepkgs
    show_note "i" $"${colorW}Retrieving package(s)...${reset}"
    get_pkgbase $@

    # clone
    for i in ${basepkgs[@]}; do
        cd "$clonedir" || exit 1
        if [[ ! -d "$i" ]]; then
            git clone --depth=1 https://aur.archlinux.org/$i.git
        else
            cd "$clonedir/$i" || exit 1
            git reset --hard HEAD -q # updated pkgver of vcs packages prevent pull
            [[ "$displaybuildfiles" = diff ]] && git rev-parse HEAD > ".git/HEAD.prev"
            git pull --ff -q
        fi
        (($? > 0)) && errgit+=($i)
    done

    # error check
    if [[ -n "${errgit[@]}" ]]; then
        for i in "${errgit[@]}"; do
            show_note "f" $"failed to retrieve ${colorW}$i${reset} package"
        done
        exit 1
    fi

    # no results check
    [[ -z "${basepkgs[@]}" ]] && show_note "e" $"no results found"
}

function _edit_pkgs_show_pkgbuild() {
    local i

    # show pkgbuild
    if do_proceed "y" $"View $i PKGBUILD?"; then
        if [[ -e "PKGBUILD" ]]; then
            $editor "PKGBUILD" && show_note "s" $"${colorW}$i${reset} PKGBUILD viewed"
            (($? > 0)) && erreditpkg+=($i)
        else
            show_note "e" $"Could not open ${colorW}$i${reset} PKGBUILD"
        fi
    fi
}

function _edit_pkgs_show_install_script() {
    local j
    
    # show install script
    if [[ -n "${installscripts[@]}" ]]; then
        for j in "${installscripts[@]}"; do
            if do_proceed "y" $"View $j script?"; then
                if [[ -e "$j" ]]; then
                    $editor "$j" && show_note "s" $"${colorW}$j${reset} script viewed"
                    (($? > 0)) && erreditpkg+=($i)
                else
                    show_note "e" $"Could not open ${colorW}$j${reset} script"
                fi
            fi
        done
    fi
}

function _edit_pkgs_show_diff() {
    local i

    # show diff
    diffcmd="git diff --no-ext-diff $(cut -f1 .git/HEAD.prev) -- . ':!\.SRCINFO'"
    if [[ -n "$(eval "$diffcmd")" ]]; then
        if do_proceed "y" $"View $i build files diff?"; then
            eval "$diffcmd"
            show_note "s" $"${colorW}$i${reset} build files diff viewed"
            viewed='true'
            (($? > 0)) && erreditpkg+=($i)
        fi
    else
        show_note "w" $"${colorW}$i${reset} build files are up-to-date -- skipping"
    fi
}

function _edit_pkgs_show_pkgbuild_and_install_script() {
    local i

    # show pkgbuild and install script
    if [[ -e "PKGBUILD" ]]; then
        $editor "PKGBUILD" && show_note "s" $"${colorW}$i${reset} PKGBUILD viewed"
        (($? > 0)) && erreditpkg+=($i)
    else
        show_note "e" $"Could not open ${colorW}$i${reset} PKGBUILD"
    fi
    if [[ -n "${installscripts[@]}" ]]; then
        for j in "${installscripts[@]}"; do
            if [[ -e "$j" ]]; then
                $editor "$j" && show_note "s" $"${colorW}$j${reset} script viewed"
                (($? > 0)) && erreditpkg+=($i)
            else
                show_note "e" $"Could not open ${colorW}$j${reset} script"
            fi
        done
    fi
}

function edit_pkgs() {
    local viewed timestamp i j erreditpkg
    # global cachedpkgs installscripts editor

    [[ $noedit ]] && return
    unset viewed

    for i in "$@"; do
        [[ " ${cachedpkgs[@]} " =~ " $i " ]] && continue
        cd "$clonedir/$i" || exit 1
        unset timestamp
        get_install_scripts $i

        if [[ ! $edit ]]; then
            if [[ ! $displaybuildfiles = none ]]; then
                if [[ $displaybuildfiles = diff && -e ".git/HEAD.prev" ]]; then
                    # show diff
                    _edit_pkgs_show_diff $i
                else
                    # show pkgbuild
                    _edit_pkgs_show_pkgbuild $i

                    # show install script
                    _edit_pkgs_show_install_script
                fi
            fi
        else
            # show pkgbuild and install script
            _edit_pkgs_show_pkgbuild_and_install_script $i
        fi
    done

    if [[ -n "${erreditpkg[@]}" ]]; then
        for i in "${erreditpkg[@]}"; do
            show_note "f" $"${colorW}$i${reset} errored on exit"
        done
        exit 1
    fi

    if [[ $displaybuildfiles = diff && $viewed = true ]]; then
        [[ $installpkg ]] && action=$"installation" || action=$"download"
        if ! do_proceed "y" $"Proceed with $action?"; then
            exit
        fi
    fi
}

function make_pkgs() {
    local oldorphanpkgs neworphanpkgs orphanpkgs oldoptionalpkgs newoptionalpkgs optionalpkgs errinstall
    local pkgsdepslist vcsclients vcschecked aurdevelpkgsAver aurdevelpkgsQver basepkgsupdate checkpkgsdepslist isaurdeps builtpkgs builtdepspkgs i j
    # global deps basepkgs sudoloop pkgsbase pkgsdeps aurpkgs aurdepspkgs depsAver builtpkg errmakepkg repoprovidersconflictingpkgs aurprovidersconflictingpkgs json

    # download
    download_pkgs ${deps[@]}
    edit_pkgs ${basepkgs[@]}

    # current orphan and optional packages
    oldorphanpkgs=($($pacmanbin -Qdtq))
    oldoptionalpkgs=($($pacmanbin -Qdttq))
    oldoptionalpkgs=($(grep -xvf <(printf '%s\n' "${oldorphanpkgs[@]}") <(printf '%s\n' "${oldoptionalpkgs[@]}")))

    # initialize sudo
    if sudo -n $pacmanbin -V > /dev/null || sudo -v; then
        [[ $sudoloop = true ]] && sudo_v &
    fi

    # split packages support
    for i in "${!pkgsbase[@]}"; do
        for j in "${!deps[@]}"; do
            [[ "${pkgsbase[$i]}" = "${pkgsbase[$j]}" ]] && [[ ! " ${pkgsdeps[@]} " =~ " ${deps[$j]} " ]] && pkgsdeps+=(${deps[$j]})
        done
        pkgsdeps+=("#")
    done
    pkgsdeps=($(sed 's/ # /\n/g' <<< ${pkgsdeps[@]} | tr -d '#' | sed '/^ $/d' | tr ' ' ',' | sed 's/^,//g;s/,$//g'))

    # reverse deps order
    basepkgs=($(awk '{for (i=NF;i>=1;i--) print $i}' <<< ${basepkgs[@]} | awk -F "\n" '{print}'))
    pkgsdeps=($(awk '{for (i=NF;i>=1;i--) print $i}' <<< ${pkgsdeps[@]} | awk -F "\n" '{print}'))

    # integrity check
    for i in "${!basepkgs[@]}"; do
        # get split packages list
        pkgsdepslist=($(awk -F "," '{for (k=1;k<=NF;k++) print $k}' <<< ${pkgsdeps[$i]}))

        # cache check
        unset builtpkg
        if [[ -z "$(grep -E "\-(bzr|git|hg|svn|daily.*|nightly.*)$" <<< ${basepkgs[$i]})" ]]; then
            for j in "${pkgsdepslist[@]}"; do
                depsAver="$(get_json "varvar" "$json" "Version" "$j")"
                [[ $PKGDEST && ! $rebuild ]] && GetBuiltPkg "$j-$depsAver" "$PKGDEST"
            done
        fi

        # install vcs clients (checking pkgbase extension only does not take fetching specific commit into account)
        unset vcsclients
        vcsclients=($(grep -E "makedepends = (bzr|git|mercurial|subversion)$" "$clonedir/${basepkgs[$i]}/.SRCINFO" | awk -F " " '{print $NF}'))
        for j in "${vcsclients[@]}"; do
            if [[ ! "${vcschecked[@]}" =~ "$j" ]]; then
                [[ -z "$(expac -Qs '%n' "^$j$")" ]] && sudo $pacmanbin -S $j --asdeps --noconfirm
                vcschecked+=($j)
            fi
        done

        if [[ ! $builtpkg || $rebuild ]]; then
            cd "$clonedir/${basepkgs[$i]}" || exit 1
            show_note "i" $"Checking ${colorW}${pkgsdeps[$i]}${reset} integrity..."
            if [[ $silent = true ]]; then
                makepkg -f --verifysource ${makeopts[@]} &>/dev/null
            else
                makepkg -f --verifysource ${makeopts[@]}
            fi
            (($? > 0)) && errmakepkg+=(${pkgsdeps[$i]})
            # extraction, prepare and pkgver update
            show_note "i" $"Preparing ${colorW}${pkgsdeps[$i]}${reset}..."
            if [[ $silent = true ]]; then
                makepkg -od --skipinteg ${makeopts[@]} &>/dev/null
            else
                makepkg -od --skipinteg ${makeopts[@]}
            fi
            (($? > 0)) && errmakepkg+=(${pkgsdeps[$i]})
        fi
    done

    if [[ -n "${errmakepkg[@]}" ]]; then
        for i in "${errmakepkg[@]}"; do
            show_note "f" $"failed to verify integrity or prepare ${colorW}$i${reset} package"
        done
        # remove sudo lock
        [[ -e "$tmpdir/pacaur.sudov.lck" ]] && rm "$tmpdir/pacaur.sudov.lck"
        exit 1
    fi

    # check database lock
    [[ -e "/var/lib/pacman/db.lck" ]] && show_note "e" $"db.lck exists in /var/lib/pacman" && exit 1

    # set build lock
    [[ -e "$tmpdir/pacaur.build.lck" ]] && show_note "e" $"pacaur.build.lck exists in $tmpdir" && exit 1
    touch "$tmpdir/pacaur.build.lck"

    # install provider packages and repo conflicting packages that makepkg --noconfirm cannot handle
    if [[ -n "${repoprovidersconflictingpkgs[@]}" ]]; then
        show_note "i" $"Installing ${colorW}${repoprovidersconflictingpkgs[@]}${reset} dependencies..."
        sudo $pacmanbin -S ${repoprovidersconflictingpkgs[@]} --ask 36 --asdeps --noconfirm
    fi

    # main
    for i in "${!basepkgs[@]}"; do

        # get split packages list
        pkgsdepslist=($(awk -F "," '{for (k=1;k<=NF;k++) print $k}' <<< ${pkgsdeps[$i]}))

        cd "$clonedir/${basepkgs[$i]}" || exit 1

        # build devel if necessary only (supported protocols only)
        unset aurdevelpkgsAver
        if [[ -n "$(grep -E "\-(bzr|git|hg|svn|daily.*|nightly.*)$" <<< ${basepkgs[$i]})" ]]; then
            # retrieve updated version
            aurdevelpkgsAver=($(makepkg --packagelist | awk -F "-" '{print $(NF-2)"-"$(NF-1)}'))
            aurdevelpkgsAver=${aurdevelpkgsAver[0]}

            # check split packages update
            unset basepkgsupdate checkpkgsdepslist
            for j in "${pkgsdepslist[@]}"; do
                aurdevelpkgsQver=$(expac -Qs '%v' "^$j$" | head -1)
                if [[ -n $aurdevelpkgsQver && $(vercmp "$aurdevelpkgsQver" "$aurdevelpkgsAver") -ge 0 ]] && [[ $needed && ! $rebuild ]]; then
                    show_note "w" $"${colorW}$j${reset} is up-to-date -- skipping"
                    continue
                else
                    basepkgsupdate='true'
                    checkpkgsdepslist+=($j)
                fi
            done
            if [[ $basepkgsupdate ]]; then
                pkgsdepslist=(${checkpkgsdepslist[@]})
            else
                continue
            fi
        fi

        # check package cache
        for j in "${pkgsdepslist[@]}"; do
            unset builtpkg
            [[ $aurdevelpkgsAver ]] && depsAver="$aurdevelpkgsAver" || depsAver="$(get_json "varvar" "$json" "Version" "$j")"
            [[ $PKGDEST && ! $rebuild ]] && GetBuiltPkg "$j-$depsAver" "$PKGDEST"
            if [[ $builtpkg ]]; then
                if [[ " ${aurdepspkgs[@]} " =~ " $j " || $installpkg ]]; then
                    show_note "i" $"Installing ${colorW}$j${reset} cached package..."
                    sudo $pacmanbin -Ud $builtpkg --ask 36 ${pacopts[@]/--quiet} --noconfirm
                    [[ ! " ${aurpkgs[@]} " =~ " $j " ]] && sudo $pacmanbin -D $j --asdeps ${pacopts[@]} &>/dev/null
                else
                    show_note "w" $"Package ${colorW}$j${reset} already available in cache"
                fi
                pkgsdeps=($(tr ' ' '\n' <<< ${pkgsdeps[@]} | sed "s/^$j,//g;s/,$j$//g;s/,$j,/,/g;s/^$j$/#/g"))
                continue
            fi
        done
        [[ "${pkgsdeps[$i]}" = '#' ]] && continue

        # build
        show_note "i" $"Building ${colorW}${pkgsdeps[$i]}${reset} package(s)..."

        # install then remove binary deps
        makeopts=(${makeopts[@]/-r/})

        if [[ ! $installpkg ]]; then
            unset isaurdeps
            for j in "${pkgsdepslist[@]}"; do
                [[ " ${aurdepspkgs[@]} " =~ " $j " ]] && isaurdeps=true
            done
            [[ $isaurdeps != true ]] && makeopts+=("-r")
        fi

        if [[ $silent = true ]]; then
            makepkg -sefc ${makeopts[@]} --noconfirm &>/dev/null
        else
            makepkg -sefc ${makeopts[@]} --noconfirm
        fi

        # error check
        if (($? > 0)); then
            errmakepkg+=(${pkgsdeps[$i]})
            continue  # skip install
        fi

        # retrieve filename
        unset builtpkgs builtdepspkgs
        for j in "${pkgsdepslist[@]}"; do
            unset builtpkg
            [[ $aurdevelpkgsAver ]] && depsAver="$aurdevelpkgsAver" || depsAver="$(get_json "varvar" "$json" "Version" "$j")"
            if [[ $PKGDEST ]]; then
                get_built_pkg "$j-$depsAver" "$PKGDEST"
            else
                get_built_pkg "$j-$depsAver" "$clonedir/${basepkgs[$i]}"
            fi
            [[ " ${aurdepspkgs[@]} " =~ " $j " ]] && builtdepspkgs+=($builtpkg) || builtpkgs+=($builtpkg)
        done

        # install
        if [[ $installpkg || -z "${builtpkgs[@]}" ]]; then
            show_note "i" $"Installing ${colorW}${pkgsdeps[$i]}${reset} package(s)..."
            # inform about missing name suffix and metadata mismatch
            if [[ -z "${builtdepspkgs[@]}" && -z "${builtpkgs[@]}" ]]; then
                show_note "f" $"${colorW}${pkgsdeps[$i]}${reset} package(s) failed to install."
                show_note "f" $"ensure package version does not mismatch between .SRCINFO and PKGBUILD"
                show_note "f" $"ensure package name has a VCS suffix if this is a devel package"
                errinstall+=(${pkgsdeps[$i]})
            else
                sudo $pacmanbin -Ud ${builtdepspkgs[@]} ${builtpkgs[@]} --ask 36 ${pacopts[@]/--quiet} --noconfirm
            fi
        fi

        # set dep status
        if [[ $installpkg ]]; then
            for j in "${pkgsdepslist[@]}"; do
                [[ ! " ${aurpkgs[@]} " =~ " $j " ]] && sudo $pacmanbin -D $j --asdeps &>/dev/null
                [[ " ${pacopts[@]} " =~ --(asdep|asdeps) ]] && sudo $pacmanbin -D $j --asdeps &>/dev/null
                [[ " ${pacopts[@]} " =~ --(asexp|asexplicit) ]] && sudo $pacmanbin -D $j --asexplicit &>/dev/null
            done
        fi
    done

    # remove AUR deps
    if [[ ! $installpkg ]]; then
        [[ -n "${aurdepspkgs[@]}" ]] && aurdepspkgs=($(expac -Q '%n' "${aurdepspkgs[@]}"))
        if [[ -n "${aurdepspkgs[@]}" ]]; then
            show_note "i" $"Removing installed AUR dependencies..."
            sudo $pacmanbin -Rsn ${aurdepspkgs[@]} --noconfirm
        fi
        # readd removed conflicting packages
        [[ -n "${aurconflictingpkgsrm[@]}" ]] && sudo $pacmanbin -S ${aurconflictingpkgsrm[@]} --ask 36 --asdeps --needed --noconfirm
        [[ -n "${repoconflictingpkgsrm[@]}" ]] && sudo $pacmanbin -S ${repoconflictingpkgsrm[@]} --ask 36 --asdeps --needed --noconfirm
    fi

    # remove locks
    rm "$tmpdir/pacaur.build.lck"
    [[ -e "$tmpdir/pacaur.sudov.lck" ]] && rm "$tmpdir/pacaur.sudov.lck"

    # new orphan and optional packages check
    orphanpkgs=($($pacmanbin -Qdtq))
    neworphanpkgs=($(grep -xvf <(printf '%s\n' "${oldorphanpkgs[@]}") <(printf '%s\n' "${orphanpkgs[@]}")))
    for i in "${neworphanpkgs[@]}"; do
        show_note "w" $"${colorW}$i${reset} is now an ${colorY}orphan${reset} package"
    done
    optionalpkgs=($($pacmanbin -Qdttq))
    optionalpkgs=($(grep -xvf <(printf '%s\n' "${orphanpkgs[@]}") <(printf '%s\n' "${optionalpkgs[@]}")))
    newoptionalpkgs=($(grep -xvf <(printf '%s\n' "${oldoptionalpkgs[@]}") <(printf '%s\n' "${optionalpkgs[@]}")))
    for i in "${newoptionalpkgs[@]}"; do
        show_note "w" $"${colorW}$i${reset} is now an ${colorY}optional${reset} package"
    done

    # makepkg and install failure check
    if [[ -n "${errmakepkg[@]}" || -n "${errinstall[@]}" ]]; then
        for i in "${errmakepkg[@]}"; do
            show_note "f" $"failed to build ${colorW}$i${reset} package(s)"
        done
        exit 1
    fi
}

# vim:set ts=4 sw=2 et:
