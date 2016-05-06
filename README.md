# PacHub

A yaourt wrapper to install PKDBUILDs from github.com.

- git *(>=2.0)*
- makepkg

## Installation

    (echo set -- install github:simonsystem/pachub && wget -qO- https://git.io/vwSrY) | 
    sudo BUILDUSER=$USER sh

## Usage

    pachub (install|touch) <uri> [merge <uri>]
    pachub (remove|info) <uri>
    pachub (list|update)

    uri:
      aur:<pkgname>
      github:<user>/<repo>
      file:///path/to/pkg
      http://example.com/repo/path
      user@git.example.com:~/repo.git