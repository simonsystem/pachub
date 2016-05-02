# Maintainer: Simon Schroeter <simon.schroeter@gmail.com>

pkgname=pachub
pkgver=1bf07b2
pkgrel=1
pkgdesc="A yaourt wrapper to install PKDBUILDs from github.com"
arch=('i686' 'x86_64')
url="https://github.com/simonsystem/pachub"
license=("GPL")
depends=('yaourt' 'git')
source=("$pkgname::git+https://github.com/simonsystem/pachub.git")
md5sums=('SKIP')
install=pachub.install
pkgver() {
    cd "$srcdir/$pkgname"
    git describe --always | sed -e 's/-/./g' -e 's/^v//' -e 's/_/./g'
}
build() {
    cd "$srcdir/$pkgname"
    make
}
package() {
    cd "$srcdir/$pkgname"
    make DESTDIR=$pkgdir install
}
