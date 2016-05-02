#!/bin/sh

set -e

GIT=git
MAKEPKG=makepkg
PACMAN=pacman
SUDO=sudo
test -n "$CONFFILE" || CONFFILE="/usr/local/etc/pachub.conf"
test ! -f "$CONFFILE" || source "$CONFFILE" 2> /dev/null
test -n "$LOCKFILE" || LOCKFILE="/var/local/pachub/lock"
test -n "$REPODIR" || REPODIR="/var/local/pachub/repo"
test -n "$BUILDUSER" || BUILDUSER="pachub"
test -n "$TMPBASE" || TMPBASE="/tmp"
umask 0022

# pachub (install|touch) <uri> [pkgbuild <path>]
# pachub list
# pachub update
# pachub info <uri>
#
# uri:
#   aur:<pkgname>
#   github:<user>/<repo>
#   file:///path/to/pkg
#   http://example.com/repo/path
#   user@git.example.com:~/repo.git

_clone() {
    test "$3" != omit || test ! -d "$2" || return 0
    test ! -d "$2" || die "Folder '$2' already exists."
    rtype=$(echo "$1" | cut -d: -f1)
    rpath=$(echo "$1" | cut -d: -f2)
    if [ "$rtype" = "aur" ]; then
        url="https://aur.archlinux.org/$rpath.git"
    elif [ "$rtype" = "github" ]; then
        url="https://github.com/$rpath.git"
    else
        url="$rtype:$rpath"
    fi
    mkdir -p "$(dirname "$2")" || true
    rm -rf "$2"
    $GIT clone "$url" "$2"
    return $?
}

_die() {
    echo "$1"
    exit 1
}

_check() {
    LOCAL=$($GIT -C "$2" rev-parse @)
    REMOTE=$($GIT -C "$2" rev-parse @{u})
    BASE=$($GIT -C "$2" merge-base @ @{u})

    test $LOCAL != $REMOTE || return 1
    test $LOCAL != $BASE || return 0
    test $REMOTE != $BASE || echo "git changes found"
    _die "git is diverged"
}

_install() {
    $GIT -C "$2" remote update
    test "$3" = force || _check "$1" || return 0
    $GIT -C "$2" pull --rebase
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
    echo $pkgname > "$2/.pkgname"
    echo $pkgver > "$2/.pkgver"
    $PACMAN --noconfirm -U "$tdir/$pkgname-$pkgver.pkg.tar.xz" || true
}

_replace() {
    cp -r "$3"/* "$2"
    $GIT -C "$2" add "*"
    $GIT -C "$2" commit -m "$(date)" || true
}

_update() {
    for dir in "$REPODIR/"*; do
        if [ "$dir" != "$REPODIR/*" -a -d "$dir" ]; then
            _install "$(basename "$dir")"
        fi
    done
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
    test -f "$2/PKGBUILD" || _die "Not found."
    ( cat "$2/PKGBUILD" && echo 'echo $pkgname' ) | sh | xargs -r $PACMAN -Qi
    return $?
}

_list() {
    for dir in "$REPODIR/"*; do
        if [ "$dir" != "$REPODIR/*" -a -d "$dir" ]; then
            basename "$dir"
        fi
    done
}

_lock() {
    test ! -f "$LOCKFILE" || die "Lockfile exists at $LOCKFILE."
    mkdir -p "$(dirname "$LOCKFILE")" || true
    touch "$LOCKFILE"
    trap _unlock EXIT
}
_unlock(){
    rm -f "$LOCKFILE"
}
if [ "$1" = "install" -a -n "$2" ]; then
    dest="$REPODIR/$(echo "$2" | tr '/' '_')"
    _lock
    _clone "$2" "$dest" omit
    if [ "$3" = "pkgbuild" -a -n "$4" ]; then
        _replace "$2" "$dest" "$4"
    fi
    _install "$2" "$dest" force 
    _unlock
elif [ "$1" = "clone" -a -n "$2" -a -n "$3" ]; then
    _clone "$2" "$3" 
elif [ "$1" = "update" -a -n "$2" ]; then
    dest="$REPODIR/$(echo "$2" | tr '/' '_')"
    _lock
    _clone "$2" "$dest" omit
    _install "$2" "$dest"
    _unlock
elif [ "$1" = "remove" -a -n "$2" ]; then
    dest="$REPODIR/$(echo "$2" | tr '/' '_')"
    _lock
    _remove "$2" "$dest"
    _unlock
elif [ "$1" = "touch" -a -n "$2" ]; then
    dest="$REPODIR/$(echo "$2" | tr '/' '_')"
    _lock
    _clone "$2" "$dest" omit
    _install "$2" "$dest" force && \
    _clean "$2" "$dest"
    _unlock
elif [ "$1" = "info" -a -n "$2" ]; then
    dest="$REPODIR/$(echo "$2" | tr '/' '_')"
    _info "$2" "$dest"
elif [ "$1" = "update" ]; then
    _update
elif [ "$1" = "list" ]; then
    _list
else
    echo "Usage: $(basename $0) (install|remove|touch|info|clone) <user>/<repo>"
    echo "       $(basename $0) (list|update)"
fi
