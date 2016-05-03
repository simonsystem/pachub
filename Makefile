
build:
install:
	install -Dm 755 pachub.sh $(DESTDIR)/usr/bin/pachub
	install -Dm 644 pachub.conf $(DESTDIR)/etc/pachub.conf
