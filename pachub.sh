#!/bin/sh

DIR="$HOME/.pachub"
PACHUB_CONF="$DIR/pachub.conf"
LOCKFILE="$DIR/.lock"
REPODIR="$DIR/repo"
if [ -f "$PACHUB_CONF" ]; then
    source "$PACHUB_CONF" 2> /dev/null || exit 1
fi
mkdir -p "$DIR"
mkdir -p "$REPODIR"

_clone() {
    test -d "$2" || git clone "https://github.com/$1.git" "$2" || return 1
}

_install() {
    git -C "$1" remote update || return 1
    if [ "$2" = "force" ]; then
        git -C "$1" pull
    else
        git -C "$1" pull | grep up-to-date && return 0
    fi
    yaourt --noconfirm -P "$1" -i
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
    pkgname=$(makepkg --printsrcinfo | grep -oP '(?<=pkgname = ).*')
    popd > /dev/null
    yaourt --noconfirm -R "$pkgname" && rm -Rf "$1"
    return $?
}

_info() {
    pushd "$1" > /dev/null
    pkgname=$(makepkg --printsrcinfo | grep -oP '(?<=pkgname = ).*')
    popd > /dev/null
    yaourt -Qi "$pkgname"
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

if [ \( "$1" = "install" -o "$1" = "update" -o "$1" = "remove" -o "$1" = "info" \) -a -n "$2" ]; then
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
        echo "Usage: $(basename $0) (install|remove|info) <user>/<repo>"
        echo "       $(basename $0) (list|update)"
    fi
fi
rm -f "$LOCKFILE"
exit $res
