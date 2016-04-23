#!/bin/sh

DIR="$HOME/.pachub"
PACHUB_CONF="$DIR/pachub.conf"
LOCKFILE="$DIR/.lock"
REPODIR="$DIR/repo"
BUILDUSER="simon"
TMPDIR="/tmp/pachub-$USER"
GIT=git
MAKEPKG=makepkg
PACMAN=pacman

if [ -f "$PACHUB_CONF" ]; then
    source "$PACHUB_CONF" 2> /dev/null || exit 1
fi
mkdir -p "$DIR"
mkdir -p "$REPODIR"

_clone() {
    user=$(echo "$1" | cut -d/ -f1)
    repo=$(echo "$1" | cut -d/ -f2)
    if [ "$user" = "aur" ]; then
        url="https://aur.archlinux.org/$repo.git"
    else
        url="https://github.com/$user/$repo.git"
    fi
    test -d "$2" || $GIT clone "$url" "$2" || return 1
}

_install() {
    $GIT -C "$1" remote update || return 1
    if [ "$2" = "force" ]; then
        $GIT -C "$1" pull
    else
        $GIT -C "$1" pull | grep up-to-date && return 0
    fi

    tdir="$TMPDIR/$(basename "$1")"

    rm -rf "$tdir" && cp -r "$1" "$tdir" && \
    pushd "$tdir" > /dev/null
    sudo -u "$BUILDUSER" $MAKEPKG -si
    popd > /dev/null

    return $?
}

_update() {
    for dir in "$REPODIR/"*/*; do
        if [ "$dir" != "$REPODIR/*/*" -a -d "$dir" ]; then
            _install "$dir" || return 1
        fi
    done
}

_remove() {
    pushd "$1" > /dev/null
    pkgname=$($MAKEPKG --printsrcinfo | grep -oP '(?<=pkgname = ).*')
    popd > /dev/null
    $PACMAN --noconfirm -R "$pkgname" && _clean "$1"
    return $?
}

_clean() {
    rm -Rf "$1"
    return $?
}

_info() {
    pushd "$1" > /dev/null
    pkgname=$($MAKEPKG --printsrcinfo | grep -oP '(?<=pkgname = ).*')
    popd > /dev/null
    $PACMAN -Qi "$pkgname"
    return $?
}

_list() {
    for dir in "$REPODIR/"*/*; do
        if [ "$dir" != "$REPODIR/*/*" -a -d "$dir" ]; then
            dirname "$dir" | xargs basename | tr '\n' '/'; basename "$dir" || return 1
        fi
    done
}

if [ -f "$LOCKFILE" ]; then
    echo "Lockfile exists at $LOCKFILE."
    exit 1
fi

touch "$LOCKFILE"
trap "rm -f '$LOCKFILE'" INT
res=0

if [ \( "$1" = "install" -o "$1" = "update" -o "$1" = "remove" -o "$1" = "touch" -o "$1" = "info" \) -a -n "$2" ]; then
    dir="$REPODIR/$2"
    _clone "$2" "$dir"
    res=$?
fi
if [ $res -eq 0 ]; then
    if [ "$1" = "install" -a -n "$2" ]; then
        _install "$dir" force
        res=$?
    elif [ "$1" = "update" -a -n "$2" ]; then
        _install "$dir"
        res=$?
    elif [ "$1" = "remove" -a -n "$2" ]; then
        _remove "$dir"
        res=$?
    elif [ "$1" = "touch" -a -n "$2" ]; then
        _install "$dir" force && \
        _clean "$dir"
        res=$?
    elif [ "$1" = "info" -a -n "$2" ]; then
        _info "$dir"
        res=$?
    elif [ "$1" = "update" ]; then
        _update
        res=$?
    elif [ "$1" = "list" ]; then
        _list
        res=$?
    else
        echo "Usage: $(basename $0) (install|remove|touch|info) <user>/<repo>"
        echo "       $(basename $0) (list|update)"
    fi
fi
rm -f "$LOCKFILE"
exit $res
