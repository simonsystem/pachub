# PacHub

A yaourt wrapper to install PKDBUILDs from github.com.

- git *(>=2.0)*

## Installation

    curl https://raw.githubusercontent.com/simonsystem/pachub/master/pachub.sh -q 2> /dev/null|
    ( echo set -- install github:simonsystem/pachub ; cat ) | sudo BUILDUSER=$USER sh

## Usage

    pachub (install|remove|touch|info) github:<user>/<repo>
    pachub (list|update)