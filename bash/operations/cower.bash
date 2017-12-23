#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

search_aur() {
    if [[ -z "$(grep -E "\-\-[r]?sort" <<< ${auropts[@]})" ]]; then
        [[ $sortorder = descending ]] && auropts+=("--rsort=$sortby") || auropts+=("--sort=$sortby");
    fi
    cower ${auropts[@]} -- $@
}

info_aur() {
    local aurinfopkgs info infolabel maxlength linfo lbytes

    readarray aurinfopkgs < <(cower ${auropts[@]} --format "%n|%v|%d|%u|%p|%L|%W|%G|%P|%D|%M|%K|%O|%C|%R|%m|%r|%o|%t|%w|%s|%a\n" $@)
    aurinfopkgsQname=($(expac -Q '%n' $@))
    aurinfopkgsQver=($(expac -Q '%v' $@))

    infolabel=($"Repository" $"Name" $"Version" $"Description" $"URL" $"AUR Page" $"Licenses" $"Keywords" $"Groups" $"Provides" $"Depends on" \
        $"Make Deps" $"Check Deps" $"Optional Deps" $"Conflicts With" $"Replaces" $"Maintainer" $"Popularity" $"Votes" $"Out of Date" $"Submitted" $"Last Modified")
    linfo=$(helper_get_length "${infolabel[@]}")
    # take into account differences between characters and bytes
    for i in "${!infolabel[@]}"; do
        (( lbytes[$i] = $(printf "${infolabel[$i]}" | wc -c) - ${#infolabel[$i]} + ${linfo} ))
    done
    maxlength=$(($(tput cols) - $linfo - 4))

    for i in "${!aurinfopkgs[@]}"; do
        IFS='|' read -ra info <<< "${aurinfopkgs[$i]}"
        # repo
        printf "${colorW}%-${lbytes[0]}s  :${reset} ${colorM}aur${reset}\n" "${infolabel[0]}"
        # name
        printf "${colorW}%-${lbytes[1]}s  :${reset} ${colorW}%s${reset}\n" "${infolabel[1]}" "${info[0]}"
        # version and installed status
        if [[ " ${aurinfopkgsQname[@]} " =~ " ${info[0]} " ]]; then
            for j in "${!aurinfopkgsQname[@]}"; do
                [[ "${aurinfopkgsQname[$j]}" != "${info[0]}" ]] && continue
                if [[ $(vercmp "${info[1]}" "${aurinfopkgsQver[$j]}") -eq 0 ]]; then
                    printf "${colorW}%-${lbytes[2]}s  :${reset} ${colorG}%s${reset} ${colorC}[${reset}${colorG}%s${reset}${colorC}]${reset}\n" "${infolabel[2]}" "${info[1]}" $"installed"
                elif [[ $(vercmp "${info[1]}" "${aurinfopkgsQver[$j]}") -lt 0 ]]; then
                    printf "${colorW}%-${lbytes[2]}s  :${reset} ${colorG}%s${reset} ${colorC}[${reset}${colorG}%s: %s${reset}${colorC}]${reset}\n" "${infolabel[2]}" "${info[1]}" $"installed" "${aurinfopkgsQver[$j]}"
                else
                    printf "${colorW}%-${lbytes[2]}s  :${reset} ${colorG}%s${reset} ${colorC}[${reset}${colorR}%s: %s${reset}${colorC}]${reset}\n" "${infolabel[2]}" "${info[1]}" $"installed" "${aurinfopkgsQver[$j]}"
                fi
            done
        else
            if [[ "${info[18]}" = 'no' ]]; then
                printf "${colorW}%-${lbytes[2]}s  :${reset} ${colorG}%s${reset}\n" "${infolabel[2]}" "${info[1]}"
            else
                printf "${colorW}%-${lbytes[2]}s  :${reset} ${colorR}%s${reset}\n" "${infolabel[2]}" "${info[1]}"
            fi
        fi
        # description
        if [[ $(helper_get_length "${info[2]}") -gt $maxlength ]]; then
            # add line breaks if needed and align text
            info[2]=$(sed 's/ /  /g' <<< ${info[2]} | fold -s -w $(($maxlength - 2)) | sed "s/^ //;2,$ s/^/\\x1b[$(($linfo + 4))C/")
        fi
        printf "${colorW}%-${lbytes[3]}s  :${reset} %s\n" "${infolabel[3]}" "${info[2]}"
        # url page
        printf "${colorW}%-${lbytes[4]}s  :${reset} ${colorC}%s${reset}\n" "${infolabel[4]}" "${info[3]}"
        printf "${colorW}%-${lbytes[5]}s  :${reset} ${colorC}%s${reset}\n" "${infolabel[5]}" "${info[4]}"
        # keywords licenses dependencies
        for j in {5..14}; do
            if [[ -n $(tr -dc '[[:print:]]' <<< ${info[$j]}) ]]; then
                # handle special optional deps cases
                if [[ "$j" = '12' ]]; then
                    info[$j]=$(sed -r 's/\S+:/\n&/2g' <<< ${info[$j]} | fold -s -w $(($maxlength - 2)) | sed "s/^ //;2,$ s/^/\\x1b[$(($linfo + 4))C/")
                else
                    # add line breaks if needed and align text
                    if [[ $(helper_get_length "${info[$j]}") -gt $maxlength ]]; then
                        info[$j]=$(sed 's/ /  /g' <<< ${info[$j]} | fold -s -w $(($maxlength - 2)) | sed "s/^ //;2,$ s/^/\\x1b[$(($linfo + 4))C/")
                    fi
                fi
                printf "${colorW}%-${lbytes[$j+1]}s  :${reset} %s\n" "${infolabel[$j+1]}" "${info[$j]}"
            else
                printf "${colorW}%-${lbytes[$j+1]}s  :${reset} %s\n" "${infolabel[$j+1]}" $"None"
            fi
        done
        # maintainer popularity votes
        for j in {15..17}; do
            printf "${colorW}%-${lbytes[$j+1]}s  :${reset} %s\n" "${infolabel[$j+1]}" "${info[$j]}"
        done
        # outofdate
        if [[ "${info[18]}" = 'no' ]]; then
            printf "${colorW}%-${lbytes[19]}s  :${reset} ${colorG}%s${reset}\n" "${infolabel[19]}" $"No"
        else
            printf "${colorW}%-${lbytes[19]}s  :${reset} ${colorR}%s${reset} [%s]\n" "${infolabel[19]}" $"Yes" $"$(date -d "@${info[19]}" "+%c")"
        fi
        # submitted modified
        printf "${colorW}%-${lbytes[20]}s  :${reset} %s\n" "${infolabel[20]}" $"$(date -d "@${info[20]}" "+%c")"
        printf "${colorW}%-${lbytes[21]}s  :${reset} %s\n" "${infolabel[21]}" $"$(date -d "@${info[21]}" "+%c")"
        echo
    done
}

# vim:set ts=4 sw=2 et:
