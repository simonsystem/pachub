
build:
install:
	install -Dm 755 pachub.sh $(DESTDIR)/usr/sbin/pachub
	install -Dm 644 pachub.conf $(DESTDIR)/etc/pachub.conf
