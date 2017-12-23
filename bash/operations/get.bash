#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

get_ignored_pkgs() {
    # global ignoredpkgs
    ignoredpkgs+=($(grep '^IgnorePkg' '/etc/pacman.conf' | awk -F '=' '{print $NF}' | tr -d "'\""))
    [[ -e "$HOME/.config/cower/config" ]] && ignoredpkgs+=($(grep '^IgnorePkg' "$HOME/.config/cower/config" | awk -F '=' '{print $NF}' | tr -d "'\""))
    ignoredpkgs=(${ignoredpkgs[@]//,/ })
}

get_ignored_grps() {
    # global ignoredgrps
    ignoredgrps+=($(grep '^IgnoreGroup' '/etc/pacman.conf' | awk -F '=' '{print $NF}' | tr -d "'\""))
    ignoredgrps=(${ignoredgrps[@]//,/ })
}

get_install_scripts() {
    local installscriptspath
    # global installscripts
    [[ ! -d "$clonedir/$1" ]] && return
    unset installscriptspath installscripts
    installscriptspath=($(find "$clonedir/$1/" -maxdepth 1 -name "*.install"))
    [[ -n "${installscriptspath[@]}" ]] && installscripts=($(basename -a ${installscriptspath[@]}))
}

get_built_pkg() {
    local pkgext
    # global builtpkg
    # check PKGEXT suffixe first, then default .xz suffixe for repository packages in pacman cache
    # and lastly all remaining suffixes in case PKGEXT is locally overridden
    for pkgext in $PKGEXT .pkg.tar.xz .pkg.tar .pkg.tar.gz .pkg.tar.bz2 .pkg.tar.lzo .pkg.tar.lrz .pkg.tar.Z; do
        builtpkg="$2/$1-${CARCH}$pkgext"
        [[ ! -f "$builtpkg" ]] && builtpkg="$2/$1-any$pkgext"
        [[ -f "$builtpkg" ]] && break;
    done
    [[ ! -f "$builtpkg" ]] && unset builtpkg
}

get_pkgbase() {
    local i
    # global json pkgsbase basepkgs
    set_json "$@"
    for i in "$@"; do
        pkgsbase+=($(get_json "varvar" "$json" "PackageBase" "$i"))
    done
    for i in "${pkgsbase[@]}"; do
        [[ " ${basepkgs[@]} " =~ " $i " ]] && continue
        basepkgs+=($i)
    done
}

# vim:set ts=4 sw=2 et:
