# PacHub

A yaourt wrapper to install PKDBUILDs from github.com.

- yaourt *(>=1.8)*
- git *(>=2.0)*

## Installation

    curl https://raw.githubusercontent.com/simonsystem/pachub/master/pachub.sh |
    ( echo set -- install simonsystem/pachub ; cat ) | sh

## Usage

    pachub (install|remove) <user>/<repo>
    pachub (list|update)
