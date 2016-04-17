
PREFIX=/usr

build:
install:
	install -Dm 755 pachub.sh $(DESTDIR)$(PREFIX)/bin/pachub
