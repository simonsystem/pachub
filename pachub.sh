#!/bin/sh
set -e

GIT=git
MAKEPKG=makepkg
PACMAN=pacman
SUDO=sudo
test -n "$CONFFILE" || CONFFILE="/etc/pachub.conf"
test ! -f "$CONFFILE" || source "$CONFFILE" 2> /dev/null
test -n "$LOCKFILE" || LOCKFILE="/var/lib/pachub/lock"
test -n "$REPODIR" || REPODIR="/var/lib/pachub/repo"
test -n "$BUILDUSER" || BUILDUSER=pachub
test -n "$TMPBASE" || TMPBASE="/tmp"
umask 0022

_usage() {
    cat <<EOT
Usage:
    $1 (install|touch) <uri> [merge <uri>]
    $1 (info|remove) <uri>
    $1 (list|update)

uri:
    aur:<pkgname>
    github:<user>/<repo>
    file:///path/to/pkg
    http://example.com/repo/path
    user@git.example.com:~/repo.git
    /path/to/pkg
EOT
}

_die() {
    echo "$1"
    return 1
}

_url() {
    case "$1" in
        aur:*)
        echo "https://aur.archlinux.org/$(echo "$1" | cut -d: -f2).git"
        ;;
        github:*)
        echo "https://github.com/$(echo "$1" | cut -d: -f2).git"
        ;;
        *)
        echo "$1"
    esac
}
_clone() {
    url="$(_url "$1")"
    test ! -d "$2" -o "$($GIT -C "$2" remote get-url origin)" = "$url" || _die "Folder '$2' already exists."
    mkdir -p "$(dirname "$2")" || true
    rm -rf "$2"
    $GIT clone "$url" "$2"
    return $?
}

_check() {
    LOCAL=$($GIT -C "$2" rev-parse @)
    REMOTE=$($GIT -C "$2" rev-parse @{u})
    BASE=$($GIT -C "$2" merge-base @ @{u})
    test $LOCAL != $REMOTE || return 1
    test $REMOTE != $BASE || return 1
}

_install() {
    $GIT -C "$2" remote remove merged 2> /dev/null || true
    $GIT -C "$2" fetch  
    test "$3" = force || _check "$1" "$2" || _die "$1: up-to-date" || return 0
    echo "$1: installing..."
    $GIT -C "$2" pull --no-edit -s recursive -X ours

    tdir="$TMPBASE/pachub-$BUILDUSER/$(basename "$2")"
    
    $SUDO -u "$BUILDUSER" sh -c "
        mkdir -p '$(dirname "$tdir")';
        rm -rf '$tdir';
        cp -r '$2' '$tdir' &&
        cd '$tdir' &&
        $MAKEPKG -s --noconfirm &&
        source '$tdir/PKGBUILD' &&
        echo \$pkgname > '$tdir/.pkgname' &&
        echo \$pkgver > '$tdir/.pkgver'"
    pkgname="$(cat "$tdir/.pkgname")"
    pkgver="$(cat "$tdir/.pkgver")"
    $PACMAN --noconfirm -U "$tdir/"*.pkg.tar.xz
    echo "$pkgname" > "$2/.pkgname"
    echo "$pkgver" > "$2/.pkgver"
}

_merge() {
    url="$(_url "$3")"
    $GIT -C "$2" remote remove merged || true
    $GIT -C "$2" remote add merged "$url"
    head=$(git symbolic-ref --short HEAD)
    $GIT -C "$2" fetch merged
    $GIT -C "$2" merge --ff-only "merged/$head"
    $GIT -C "$2" remote remove merged
}

_update() {
    res=0
    for dir in "$REPODIR/"*; do
        if [ "$dir" != "$REPODIR/*" -a -d "$dir" ]; then
            _install "$(basename "$dir")" "$dir" || res=1
        fi
    done
    return $res
}

_remove() {
    test -d "$2" || _die "Not found."
    pkgname="$(cat "$dest/.pkgname")"
    $PACMAN --noconfirm -R "$pkgname" || true
    _clean "$1"
    return $?
}

_clean() {
    dest="$REPODIR/$(echo "$1" | tr '/' '_')"
    rm -Rf "$dest"
    return $?
}

_info() {
    test -f "$2/.pkgname" || _die "Not found."
    $PACMAN -Qi "$(cat "$2/.pkgname")"
    return $?
}

_list() {
    for dir in "$REPODIR/"*; do
        if [ "$dir" != "$REPODIR/*" -a -d "$dir" ]; then
            echo -n "$(basename "$dir")"
            if [ -f "$dir/.pkgname" ]; then
                echo -n " => $(cat "$dir/.pkgname")"
            fi
            echo
        fi
    done
}

_lock() {
    test $(id -u) -eq 0 || _die "Must be root."
    test ! -f "$LOCKFILE" || _die "Lockfile exists at $LOCKFILE."
    mkdir -p "$(dirname "$LOCKFILE")" || true
    touch "$LOCKFILE"
    trap _unlock EXIT
}

_unlock() {
    for dir in "$REPODIR/"*; do
        if [ "$dir" != "$REPODIR/*" -a -d "$dir" -a ! -f "$dir/.pkgname" ]; then
            rm -Rf "$dir"
        fi
    done
    rm -f "$LOCKFILE"
}

_log() {
    test -d "$2" || _die "Not found."
    $GIT -C "$2" log --graph --abbrev-commit --decorate --oneline --all
}

_dir() {
    echo -n "$REPODIR/"
    echo "$1" | tr '/' '_'
}

if [ "$1" = "install" -a -n "$2" ]; then
    dest="$(_dir "$2")"
    _lock
    _clone "$2" "$dest" omit
    if [ "$3" = "merge" -a -n "$4" ]; then
        _merge "$2" "$dest" "$4"
    fi
    _install "$2" "$dest" force 
    _unlock
elif [ "$1" = "clone" -a -n "$2" -a -n "$3" ]; then
    _clone "$2" "$3" 
elif [ "$1" = "update" -a -n "$2" ]; then
    dest="$(_dir "$2")"
    _lock
    _clone "$2" "$dest" omit
    _install "$2" "$dest"
    _unlock
elif [ "$1" = "remove" -a -n "$2" ]; then
    dest="$(_dir "$2")"
    _lock
    _remove "$2" "$dest"
    _unlock
elif [ "$1" = "touch" -a -n "$2" ]; then
    dest="$(_dir "$2")"
    _lock
    _clone "$2" "$dest" omit
    _install "$2" "$dest" force
    _clean "$2" "$dest"
    _unlock
elif [ "$1" = "log" -a -n "$2" ]; then
    dest="$(_dir "$2")"
    _log "$2" "$dest"
elif [ "$1" = "info" -a -n "$2" ]; then
    dest="$(_dir "$2")"
    _info "$2" "$dest"
elif [ "$1" = "update" ]; then
    _lock
    _update
    _unlock
elif [ "$1" = "list" ]; then
    _list
else
    _usage "$(basename $0)"
fi
