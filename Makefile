
build:
install:
	install -Dm 755 pachub.sh $(DESTDIR)/usr/bin/pachub
	install -dm 755 $(DESTDIR)/var/lib/pachub
	install -Dm 644 pachub.conf $(DESTDIR)/etc/pachub.conf
