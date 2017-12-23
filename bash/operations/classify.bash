#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

classify_pkgs() {
    local noaurpkgs norepopkgs
    # global aurpkgs repopkgs
    if [[ $fallback = true ]]; then
        [[ $repo ]] && repopkgs=(${pkgs[@]})
        if [[ $aur ]]; then
            for i in "${pkgs[@]}"; do
                [[ $i == aur/* ]] && aurpkgs+=(${i:4}) && continue # search aur/pkgs in AUR
                aurpkgs+=($i)
            done
        fi
        if [[ ! $repo && ! $aur ]]; then
            unset noaurpkgs
            for i in "${pkgs[@]}"; do
                [[ $i == aur/* ]] && aurpkgs+=(${i:4}) && continue # search aur/pkgs in AUR
                noaurpkgs+=($i)
            done
            [[ -n "${noaurpkgs[@]}" ]] && norepopkgs=($(LANG=C $pacmanbin -Sp ${noaurpkgs[@]} 2>&1 >/dev/null | awk '{print $NF}'))
            for i in "${norepopkgs[@]}"; do
                [[ ! " ${noaurpkgs[@]} " =~ [a-zA-Z0-9\.\+-]+\/$i[^a-zA-Z0-9\.\+-] ]] && aurpkgs+=($i) # do not search repo/pkgs in AUR
            done
            repopkgs=($(grep -xvf <(printf '%s\n' "${aurpkgs[@]}") <(printf '%s\n' "${noaurpkgs[@]}")))
        fi
    else
        if [[ ! $aur ]]; then
            repopkgs=(${pkgs[@]})
        else
            for i in "${pkgs[@]}"; do
                [[ $i == aur/* ]] && aurpkgs+=(${i:4}) && continue # search aur/pkgs in AUR
                aurpkgs+=($i)
            done
        fi
    fi
}

# vim:set ts=4 sw=2 et:
