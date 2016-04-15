#!/bin/sh

mkdir -p $HOME/.pachub
LOCKFILE=$HOME/.pachub/packages.lock
LISTFILE=$HOME/.pachub/packages.list

makehub() {
    name=$(echo "$1" |cut -d "/" -f 2)
    tmp="/tmp/pachub-$USER"
    dir="$tmp/$name"
    if [ -d "$dir" ]; then
        pushd "$dir" > /dev/null
        git pull
        res=$?
        popd > /dev/null
    else
        git clone "https://github.com/$1.git" "$dir"
        res=$?
    fi
    if [ $res -eq 0 ]; then
        yaourt --noconfirm -P "$dir"
        res=$?
    fi
    return $res
}

if [ -f "$LOCKFILE" ]; then
    echo "Lockfile exists at $LOCKFILE."
    exit 1
fi

test -f "$LISTFILE" || touch "$LISTFILE"
touch "$LOCKFILE"
trap "rm -f '$LOCKFILE'" INT

if [ "$1" = "install" ]; then
    makehub "$2"
    res=$?
    test $res -eq 0 && echo "$2" > "$LISTFILE"
elif [ "$1" = "remove" ]; then
    if grep "^los$" "$LISTFILE"; then
        name=$(echo "$1" |cut -d "/" -f 2)
        yaourt --noconfirm -R "$name"
        res=$?
        grep -v "^los$" "$LISTFILE" > "$LISTFILE.new"
        cp -f "$LISTFILE.new" "$LISTFILE"
        rm -f "$LOCKFILE" "$LISTFILE.new"
    else
        echo "Not found."
        res=1
    fi
elif [ "$1" = "update" ]; then
    cat "$LISTFILE" | while read line; do
        makehub "$2"
        res=$?
        test $res -eq 0 || break
    done
elif [ "$1" = "list" ]; then
    echo "Package list:"
    cat "$LISTFILE"
else
    echo "Usage: $0 (install|remove) <user>/<repo>"
    echo "       $0 (list|update)"
fi

rm -f "$LOCKFILE"

exit $res
