#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

# This function need a lot of refactoring.
# But I still can't find the elegant way to solve the shift issue.
# I'll be back

function get_options_from_arguments() {

# get options
count=0
# ! : indirect expansion
while [[ -n "${!OPTIND}" ]]; do
    case "${!OPTIND}" in
        sync)      operation=sync;  aur='1';    
                   installpkg=true;                    
                   shift $OPTIND;;
        info)      operation=sync;  aur='1'; 
                   info=true;       auropts+=("-i");                    
                   shift $OPTIND;;
        search)    operation=sync;  aur='1'; 
                   search=true;     auropts+=("-s");                    
                   shift $OPTIND;;
        buildonly) operation=sync;  aur='1'; 
                   shift $OPTIND;;
        upgrade)   operation=sync;  aur='1'; 
                   upgrade=true;    installpkg=true; selective=true; 
                   shift $OPTIND;;
        check)     operation=upgrades; 
                   pacopts+=("--foreign"); 
                   shift $OPTIND;;
        clean)     operation=sync;  aur='1';   
                   cleancache=true; count=1; 
                   shift $OPTIND;;
        cleanall)  operation=sync;  aur='1';    
                   cleancache=true; count=2; 
                   shift $OPTIND;;
    esac

    while getopts "sidmykufecqrahvxVDFQRSTUbglnoptw-:" OPT; do
        pacmanarg+=("-$OPT");
        case "$OPT" in
            -)
                case "$OPTARG" in
                    search) 
                        [[ $pac || $pacS || $pacQ ]] && pacopts+=("--search");
                        [[ $pacS ]] && operation=sync && search=true && auropts+=("-s");
                        [[ $pac || $pacQ || $pacS ]] && continue || deprecated='1'; 
                        operation=sync; search=true; auropts+=("-s"); aur='1';;
                    info) 
                        [[ $pac || $pacS || $pacQ ]] && pacopts+=("--info");
                        [[ $pacS ]] && operation=sync && info=true && auropts+=("-i");
                        [[ $pac || $pacQ || $pacS ]] && continue || deprecated='1'; 
                        operation=sync; info=true; auropts+=("-i"); aur='1';;
                    download) 
                        deprecated='1'; 
                        operation=download && ((count++));;
                    makepkg) 
                        deprecated='1'; 
                        operation=sync; aur='1';;
                    sync) 
                        [[ $pac || $pacS || $pacQ ]] && pacopts+=("--sync");
                        [[ $pacS ]] && operation=sync; installpkg=true; aur='1';
                        [[ $pac || $pacQ || $pacS ]] && continue || deprecated='1'; 
                        operation=sync; installpkg=true; aur='1';;
                    check) 
                        [[ $pac || $pacS || $pacQ ]] && pacopts+=("--check");
                        [[ $pac || $pacQ || $pacS ]] && continue || deprecated='1'; 
                        operation=upgrades; pacopts+=("--foreign");;
                    update) 
                        deprecated='1'; 
                        operation=sync; upgrade=true; installpkg=true; selective=true; aur='1';;
                    edit) 
                        edit=true; 
                        [[ ! $pacQ && ! $operation ]] && operation=editpkg;;
                    quiet) 
                        quiet=true; pacopts+=("--quiet"); auropts+=("-q"); 
                        [[ $search || $operation = upgrades ]] && color=never;;
                    repo) 
                        repo='1';;
                    aur) 
                        aur='1';;
                    devel) 
                        devel=true;;
                    foreign) 
                        [[ $pacQ ]] && pacopts+=("--foreign"); 
                        foreign=true;;
                    ignore=?*) 
                        ignoredpkgs+=(${OPTARG#*=}); 
                        ignoreopts+=("--ignore ${OPTARG#*=}");;
                    ignore) 
                        ignoredpkgs+=(${!OPTIND}); 
                        ignoreopts+=("--ignore ${!OPTIND}"); shift;;
                    color=?*) 
                        color=${OPTARG#*=}; 
                        pacopts+=("--color ${OPTARG#*=}") && auropts+=("--color=${OPTARG#*=}");;
                    color) 
                        color=${!OPTIND}; 
                        pacopts+=("--color ${!OPTIND}") && auropts+=("--color=${!OPTIND}"); shift;;
                    ignore-ood) 
                        auropts+=("--ignore-ood");;
                    no-ignore-ood) 
                        auropts+=("--no-ignore-ood");;
                    literal) 
                        auropts+=("--literal");;
                    sort=?*) 
                        auropts+=("--sort ${OPTARG#*=}");;
                    sort) 
                        auropts+=("--sort ${!OPTIND}"); shift;;
                    rsort=?*) 
                        auropts+=("--rsort ${OPTARG#*=}");;
                    rsort) 
                        auropts+=("--rsort ${!OPTIND}"); shift;;
                    by=?*) 
                        auropts+=("--by ${OPTARG#*=}");;
                    by) 
                        auropts+=("--by ${!OPTIND}"); shift;;
                    asdep|asdeps) 
                        pacopts+=("--asdeps"); makeopts+=("--asdeps");;
                    needed) 
                        needed=true; pacopts+=("--needed"); makeopts+=("--needed");;
                    nodeps) 
                        nodeps=true; pacopts+=("--nodeps"); makeopts+=("--nodeps"); ((count++));;
                    assume-installed=?*) 
                        assumeinstalled+=(${OPTARG#*=}); pacopts+=("--assume-installed ${OPTARG#*=}");;
                    assume-installed) 
                        assumeinstalled+=(${!OPTIND}); pacopts+=("--assume-installed ${!OPTIND}"); shift;;
                    noconfirm) 
                        noconfirm=true; pacopts+=("--noconfirm");;
                    noedit) 
                        noedit=true;;
                    rebuild) 
                        rebuild=true;;
                    silent) 
                        silent=true; makeopts+=("--log");;
                    domain=?*) 
                        aururl=${OPTARG#*=}; auropts+=("--domain ${OPTARG#*=}");;
                    domain) 
                        aururl=${!OPTIND}; auropts+=("--domain ${!OPTIND}"); shift;;
                    root=?*) 
                        pacopts+=("--root ${OPTARG#*=}");;
                    root) 
                        pacopts+=("--root ${!OPTIND}"); shift;;
                    version) 
                        show_version; exit;;
                    help) 
                        show_usage; exit;;
                    *) pacopts+=("--$OPTARG");;
                esac;;
            s)  [[ $pacS ]] && operation=sync && search=true && auropts+=("-s");
                [[ $pac || $pacQ || $pacS ]] && continue || deprecated='1'; 
                operation=sync; search=true; auropts+=("-s"); aur='1';;
            i)  [[ $pacS ]] && operation=sync && info=true && auropts+=("-i");
                [[ $pac || $pacQ || $pacS ]] && continue || deprecated='1'; 
                operation=sync; info=true; auropts+=("-i"); aur='1';;
            d)  [[ $pacS ]] && nodeps=true && pacopts+=("--nodeps") && makeopts+=("--nodeps") && ((count++));
                [[ $pac || $pacQ || $pacS ]] && continue || deprecated='1'; 
                operation=download && ((count++));;
            m)  [[ $pac || $pacQ || $pacS ]] && continue || deprecated='1'; 
                operation=sync; aur='1';;
            y)  [[ $pacS ]] && operation=sync && refresh=true;
                [[ $pac || $pacQ || $pacS ]] && continue || deprecated='1'; 
                operation=sync; installpkg=true; aur='1';;
            k)  [[ $pac || $pacQ || $pacS ]] && continue || deprecated='1'; 
                operation=upgrades; auropts+=("-uq"); pacopts+=("--foreign");;
            u)  [[ $pacQ ]] && operation=upgrades;
                [[ $pacS ]] && operation=sync && upgrade=true;
                [[ $pac || $pacQ || $pacS ]] && continue || deprecated='1'; 
                operation=sync; upgrade=true; installpkg=true; selective=true; aur='1';;
            e)  [[ $pacQ ]] && pacopts+=("--explicit") && continue || edit=true;
                [[ ! $operation ]] && operation=editpkg;;
            c)  [[ $pacS ]] && operation=sync && cleancache=true && ((count++));
                [[ $pac || $pacQ || $pacS ]] && continue;;
            q)  quiet=true; pacopts+=("--quiet"); auropts+=("-q"); 
                [[ $search || $operation = upgrades ]] && color=never;;
            r)  
                repo='1';;
            a)  
                aur='1';;
            Q)  
                pacQ='1';;
            S)  
                pacS='1'; operation=sync;
                [[ "${opts[@]}" =~ "w" ]] && continue || installpkg=true;
                [[ "${opts[@]}" =~ "g" || "${opts[@]}" =~ "l" || "${opts[@]}" =~ "p" ]] && unset operation;;
            h)  
                [[ "${opts[@]}" =~ ^-[A-Z] ]] && unset operation && continue || message_usage; 
                exit;;
            v)  
                [[ "${opts[@]}" =~ ^-[A-Z] ]] && continue || message_version; 
                exit;;
            [A-Z]) 
                pac='1';;
            *)  
                continue;;
        esac
    done
    # packages
    [[ -z "${!OPTIND}" ]] && break || pkgs+=("${!OPTIND}")
    shift $OPTIND
    OPTIND=1
done
}

# vim:set ts=4 sw=2 et:
