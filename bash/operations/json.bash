#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

# This lib used a lot in dependencies

declare -A jsoncache
function set_json() {
    if [[ $# -eq 0 ]]; then
        json="{}"
    else
        # global json
        if [[ -z "${jsoncache[$@]}" ]]; then
            jsoncache[$@]="$(download_json $@)"
        fi
        json="${jsoncache[$@]}"
    fi
}

function download_json() {
    local urlencodedpkgs urlargs urlcurl urlarg urlmax j
    urlencodedpkgs=($(sed 's/+/%2b/g;s/@/%40/g' <<< $@)) # pkgname consists of alphanum@._+-
    urlarg='&arg[]='
    urlargs="$(printf "$urlarg%s" "${urlencodedpkgs[@]}")"
    urlmax=4400
    
    # example of https://$aururl$aurrpc$urlargs"
    # https://aur.archlinux.org/rpc/?type=info&v=5&arg[]=xmonad-git
    
    # ensure the URI length is shorter than 4444 bytes (44 for AUR path)
    if [[ "${#urlargs}" -lt $urlmax ]]; then
        curl -sfg --compressed -C 0 -w "" "https://$aururl$aurrpc$urlargs"
    else
        # split and merge json stream
        j=0
        for i in "${!urlencodedpkgs[@]}"; do
            if [[ $((${#urlcurl[$j]} + ${#urlencodedpkgs[$i]} + ${#urlarg})) -ge $urlmax ]]; then
                j=$(($j + 1))
            fi
            urlcurl[$j]=${urlcurl[$j]}${urlarg}${urlencodedpkgs[$i]}
        done
        urlargs="$(printf "https://$aururl$aurrpc%s " "${urlcurl[@]}")"
        curl -sfg --compressed -C 0 -w "" $urlargs | sed 's/\(]}{\)\([A-Za-z0-9":,]\+[[]\)/,/g;s/\("resultcount":\)\([0-9]\+\)/"resultcount":0/g'
    fi
}

function get_json() {
    # Here Strings <<<
    if json_verify -q <<< "$2"; then
        case "$1" in
            var)
                json_reformat <<< "$2" | tr -d "\", " | grep -Po "$3:.*" | sed -r "s/$3:/$3#/g" | awk -F "#" '{print $2}';;
            varvar)
                json_reformat <<< "$2" | tr -d ", " | sed -e "/\"Name\":\"$4\"/,/}/!d" | \
                tr -d "\"" | grep -Po "$3:.*" | sed -r "s/$3:/$3#/g" | awk -F "#" '{print $2}';;
            array)
                json_reformat <<< "$2" | tr -d ", " | sed -e "/^\"$3\"/,/]/!d" | tr -d '\"' \
                | tr '\n' ' ' | sed "s/] /]\n/g" | cut -d' ' -f 2- | tr -d '[]"' | tr -d '\n';;
            arrayvar)
                json_reformat <<< "$2" | tr -d ", " | sed -e "/\"Name\":\"$4\"/,/}/!d" | \
                sed -e "/^\"$3\"/,/]/!d" | tr -d '\"' | tr '\n' ' ' | cut -d' ' -f 2- | tr -d '[]';;
        esac
    else
        show_note "e" $"Failed to parse JSON"
    fi
}

# vim:set ts=4 sw=2 et:
