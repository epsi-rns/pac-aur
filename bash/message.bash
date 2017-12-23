#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

function message_usage() {
    cat <<-EOF
usage:  pacaur <operation> [options] [target(s)] -- See also pacaur(8)
operations:
 pacman extension
   -S, -Ss, -Si, -Sw, -Su, -Qu, -Sc, -Scc
                    extend pacman operations to the AUR
 AUR specific
   sync             clone, build and install target(s)
   search           search AUR for matching strings
   info             view package information
   buildonly        clone and build target(s)
   upgrade          upgrade AUR package(s)
   check            check for AUR upgrade(s)
   clean            clean AUR package(s) and clone(s)
   cleanall         clean all AUR packages and clones
 general
   -v, --version    display version information
   -h, --help       display help information

options:
 pacman extension - can be used with the -S, -Ss, -Si, -Sw, -Su, -Sc, -Scc operations
   -a, --aur        only search, build, install or clean target(s) from the AUR
   -r, --repo       only search, build, install or clean target(s) from the repositories
 general
   -e, --edit       edit target(s) PKGBUILD and view install script
   -q, --quiet      show less information for query and search
   --devel          consider AUR development packages upgrade
   --foreign        consider already installed foreign dependencies
   --ignore         ignore a package upgrade (can be used more than once)
   --needed         do not reinstall already up-to-date target(s)
   --noconfirm      do not prompt for any confirmation
   --noedit         do not prompt to edit files
   --rebuild        always rebuild package(s)
   --silent         silence output

EOF
}

function message_version() {
    echo "pacaur $version"
}

function message_deprecated() {
    show_note "w" "${colorW}show_note:${reset} The ${colorW}AUR specific commands${reset} short options ${colorW}-y, -s, -i, -d, -m, -u, k${reset} and their"
    show_note "w" "respective long options are now ${colorY}deprecated${reset} and ${colorY}will be removed${reset} in a future release."
    show_note "w" "Please use the new explicit ${colorW}sync, search, info, buildonly, update, check, clean, cleanall${reset} commands."
}

# vim:set ts=4 sw=2 et:
