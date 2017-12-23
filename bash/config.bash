#!/usr/bin/env bash
# based on pacaur, original code at https://github.com/rmarquis/pacaur

#
# Config
#

# sanitize
unset aur cleancache devel edit info installpkg foreign needed noconfirm nodeps noedit
unset operation pac pacQ pacS quiet rebuild refresh repo search selective upgrade

# internationalization
#LC_COLLATE=C                                # getopts sorting
#TEXTDOMAIN='pacaur'
#TEXTDOMAINDIR='/usr/share/locale'

# determine config location
if [[ -n "${XDG_CONFIG_DIRS}" ]]; then
    for i in ${XDG_CONFIG_DIRS//:/ }; do
        [[ -d "$i/pacaur" ]] && export XDG_CONFIG_DIRS="$i" && break
    done
fi
configdir="${XDG_CONFIG_DIRS:-/etc/xdg}/pacaur"
userconfigdir="${XDG_CONFIG_HOME:-${HOME}/.config}/pacaur"
userpacmandir="${XDG_CONFIG_HOME:-${HOME}/.config}/pacman"
usercachedir="${XDG_CACHE_HOME:-${HOME}/.cache}/pacaur"
tmpdir="${XDG_RUNTIME_DIR:-/tmp}"

# preserve environment variables
# -n : string is not null.
[[ -n ${PACMAN} ]] && _PACMAN=${PACMAN}
[[ -n ${PKGDEST} ]] && _PKGDEST=${PKGDEST}
[[ -n ${SRCDEST} ]] && _SRCDEST=${SRCDEST}
[[ -n ${SRCPKGDEST} ]] && _SRCPKGDEST=${SRCPKGDEST}
[[ -n ${LOGDEST} ]] && _LOGDEST=${LOGDEST}
[[ -n ${BUILDDIR} ]] && _BUILDDIR=${BUILDDIR}
[[ -n ${PKGEXT} ]] && _PKGEXT=${PKGEXT}
[[ -n ${SRCEXT} ]] && _SRCEXT=${SRCEXT}
[[ -n ${GPGKEY} ]] && _GPGKEY=${GPGKEY}
[[ -n ${PACKAGER} ]] && _PACKAGER=${PACKAGER}
[[ -n ${CARCH} ]] && _CARCH=${CARCH}

# source makepkg variables
# -r : file has read permission
if [[ -r "$MAKEPKG_CONF" ]]; then
    source "$MAKEPKG_CONF"
else
    source /etc/makepkg.conf
    if [[ -r "$userpacmandir/makepkg.conf" ]]; then
        source "$userpacmandir/makepkg.conf"
    elif [[ -r "$HOME/.makepkg.conf" ]]; then
        source "$HOME/.makepkg.conf"
    fi
fi

# restore environment variables
PACMAN=${_PACMAN:-$PACMAN}
PKGDEST=${_PKGDEST:-$PKGDEST}
SRCDEST=${_SRCDEST:-$SRCDEST}
SRCPKGDEST=${_SRCPKGDEST:-$SRCPKGDEST}
LOGDEST=${_LOGDEST:-$LOGDEST}
BUILDDIR=${_BUILDDIR:-$BUILDDIR}
PKGEXT=${_PKGEXT:-$PKGEXT}
SRCEXT=${_SRCEXT:-$SRCEXT}
GPGKEY=${_GPGKEY:-$GPGKEY}
PACKAGER=${_PACKAGER:-$PACKAGER}
CARCH=${_CARCH:-$CARCH}

# set default config variables
editor="${VISUAL:-${EDITOR:-nano}}"         # build files editor
displaybuildfiles=diff                      # display build files (none|diff|full)
fallback=true                               # pacman fallback to the AUR
silent=false                                # silence output
sortby=popularity                           # sort method (name|votes|popularity)
sortorder=descending                        # sort order (ascending|descending)
sudoloop=true                               # prevent sudo timeout

# set variables
pacmanbin="${PACMAN:-pacman}"               # pacman binary
clonedir="${AURDEST:-$usercachedir}"        # clone directory

# set AUR variables
aururl="aur.archlinux.org"
aurrpc="/rpc/?type=info&v=5"

# source xdg config
source "$configdir/config"
# -r : file has read permission
[[ -r "$userconfigdir/config" ]] && source "$userconfigdir/config"

# set up directories
# -d : file is a directory
[[ ! -d "$clonedir" ]] && mkdir -p "$clonedir" -m 700

# vim:set ts=4 sw=2 et:
