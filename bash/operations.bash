#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

trap do_cancel INT
do_cancel() {
    echo
    [[ -e "$tmpdir/pacaur.build.lck" ]] && rm "$tmpdir/pacaur.build.lck"
    [[ -e "$tmpdir/pacaur.sudov.lck" ]] && rm "$tmpdir/pacaur.sudov.lck"
    exit
}

function _operation_download() {
    # download (-d): option handling (deprecated)

    classify_pkgs ${pkgs[@]}
    if [[ $count -gt 1 ]]; then
        deps_solver
        download_pkgs ${deps[@]}
    else
        if [[ -n "${aurpkgs[@]}" ]]; then
            download_pkgs ${aurpkgs[@]}
        else
            exit 1
        fi
    fi
    edit_pkgs ${pkgsbase[@]}
}

function _operation_editpkg() {
    # edit (-e): option handling

    get_pkgbase ${pkgs[@]}
    edit_pkgs ${pkgsbase[@]}
}

function _operation_sync_search() {
    # search (-Ss, -s): option handling

    if [[ ! $aur ]]; then
        if [[ $refresh ]]; then
            sudo $pacmanbin ${pacmanarg[@]} ${pacopts[@]} ${ignoreopts[@]} -- ${pkgs[@]}
        else
            $pacmanbin ${pacmanarg[@]} ${pacopts[@]} ${ignoreopts[@]} -- ${pkgs[@]}
        fi
        exitrepo=$?
    fi
    if [[ ! $repo && ($fallback = true || $aur) ]]; then
        search_aur ${pkgs[@]}
        exitaur=$?
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

function _operation_sync_info() {
    # info (-Si, -i): option handling

    if [[ -z "${pkgs[@]}" ]]; then
        $pacmanbin ${pacmanarg[@]} ${pacopts[@]} ${ignoreopts[@]}
    else
        classify_pkgs ${pkgs[@]}
    fi
    if [[ -n "${repopkgs[@]}" ]]; then
        [[ $refresh ]] && sudo $pacmanbin ${pacmanarg[@]} ${pacopts[@]} ${ignoreopts[@]} ${repopkgs[@]}
        [[ ! $refresh ]] && $pacmanbin ${pacmanarg[@]} ${pacopts[@]} ${ignoreopts[@]} ${repopkgs[@]}
    fi
    if [[ -n "${aurpkgs[@]}" ]]; then
        [[ $refresh ]] && [[ -z "${repopkgs[@]}" ]] && sudo $pacmanbin -Sy ${pacopts[@]} ${ignoreopts[@]}
        if [[ $fallback = true && ! $aur ]]; then
            if [[ "${#aurpkgs[@]}" -gt 1 ]]; then
                show_note "w" $"Packages ${colorW}${aurpkgs[*]}${reset} not found in repositories, trying ${colorM}AUR${reset}..."
            else
                show_note "w" $"Package ${colorW}${aurpkgs[*]}${reset} not found in repositories, trying ${colorM}AUR${reset}..."
            fi
        fi
        # display info without buffer delay
        tmpinfo=$(mktemp "$tmpdir/pacaur.infoaur.XXXX") && info_aur ${aurpkgs[@]} > $tmpinfo && cat $tmpinfo && rm $tmpinfo
    fi
}

function _operation_sync_cleancache() {
    # clean (-Sc): option handling

    [[ ! $aur ]] && sudo $pacmanbin ${pacmanarg[@]} ${pacopts[@]} ${ignoreopts[@]} ${repopkgs[@]}
    [[ ! $repo ]] && [[ $fallback = true || $aur ]] && clean_cache ${pkgs[@]}
}

# Using do_core function
function _operation_sync_upgrade() {
    # sysupgrade (-Su, -u): option handling

    [[ -n "${pkgs[@]}" ]] && classify_pkgs ${pkgs[@]}
    if [[ ! $aur ]]; then
        sudo $pacmanbin ${pacmanarg[@]} ${pacopts[@]} ${ignoreopts[@]} ${repopkgs[@]}
        (($? > 0)) && [[ $repo ]] && exit 1
        [[ $repo ]] && exit 0
    fi
    [[ ! $repo ]] && [[ $aur ]] && [[ $refresh ]] && [[ -z "${repopkgs[@]}" ]] && sudo $pacmanbin -Sy ${pacopts[@]} ${ignoreopts[@]}
    if [[ -n "${aurpkgs[@]}" ]] && [[ $fallback = true && ! $aur ]]; then
        if [[ "${#aurpkgs[@]}" -gt 1 ]]; then
            show_note "w" $"Packages ${colorW}${aurpkgs[*]}${reset} not found in repositories, trying ${colorM}AUR${reset}..."
        else
            show_note "w" $"Package ${colorW}${aurpkgs[*]}${reset} not found in repositories, trying ${colorM}AUR${reset}..."
        fi
    fi
    [[ ! $repo ]] && [[ $fallback = true || $aur ]] && do_core
}

# Using do_core function
function _operation_sync_else() {
    # sync (-S, -y), downloadonly (-Sw, -m), refresh (-Sy):: option handling

    if [[ -z "${pkgs[@]}" ]]; then
        sudo $pacmanbin ${pacmanarg[@]} ${pacopts[@]} ${ignoreopts[@]}
    else
        classify_pkgs ${pkgs[@]}
    fi
    [[ -n "${repopkgs[@]}" ]] && sudo $pacmanbin ${pacmanarg[@]} ${pacopts[@]} ${ignoreopts[@]} ${repopkgs[@]}
    if [[ -n "${aurpkgs[@]}" ]]; then
        [[ $refresh ]] && [[ -z "${repopkgs[@]}" ]] && sudo $pacmanbin -Sy ${pacopts[@]} ${ignoreopts[@]}
        if [[ $fallback = true && ! $aur ]]; then
            if [[ "${#aurpkgs[@]}" -gt 1 ]]; then
                show_note "w" $"Packages ${colorW}${aurpkgs[*]}${reset} not found in repositories, trying ${colorM}AUR${reset}..."
            else
                show_note "w" $"Package ${colorW}${aurpkgs[*]}${reset} not found in repositories, trying ${colorM}AUR${reset}..."
            fi
        fi
        do_core
    fi
}

function _operation_else() {
    # others options handling

    if [[ -n "$(grep -e "-[F]" <<< ${pacmanarg[@]})" && -n "$(grep -e "-[y]" <<< ${pacmanarg[@]})" ]]; then
        sudo $pacmanbin ${pacmanarg[@]} ${pacopts[@]} "${pkgs[@]}"
    elif [[ -z "${pkgs[@]}" || -n "$(grep -e "-[DFQTglp]" <<< ${pacmanarg[@]})" ]] && [[ ! " ${pacopts[@]} " =~ --(asdep|asdeps) && ! " ${pacopts[@]} " =~ --(asexp|asexplicit) ]]; then
        $pacmanbin ${pacmanarg[@]} ${pacopts[@]} ${ignoreopts[@]} "${pkgs[@]}"
    else
        sudo $pacmanbin ${pacmanarg[@]} ${pacopts[@]} ${ignoreopts[@]} "${pkgs[@]}"
    fi
}

# ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- ----
# the whole operations

function execute_operation() {
    local operation=$1

    # operations
    case $operation in
        download)
            # download (-d): option handling (deprecated)
            _operation_download
            exit;;
        editpkg)
            # edit (-e): option handling
            _operation_editpkg
            exit;;
        sync)
            # search (-Ss, -s): option handling
            if [[ $search ]]; then
                _operation_sync_search
            # info (-Si, -i): option handling
            elif [[ $info ]]; then
                _operation_sync_info
            # clean (-Sc): option handling
            elif [[ $cleancache ]]; then
                _operation_sync_cleancache
            # sysupgrade (-Su, -u): option handling
            elif [[ $upgrade ]]; then
                _operation_sync_upgrade
            # sync (-S, -y), downloadonly (-Sw, -m), refresh (-Sy)
            else
                _operation_sync_else
            fi
            exit;;
        upgrades)
            # upgrades (-Qu, -k): option handling
            check_updates ${pkgs[@]}
            exit;;
        *)  # others operations: option handling
            _operation_else
            exit;;
    esac
}

# vim:set ts=4 sw=2 et:
