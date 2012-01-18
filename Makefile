SPECVERSION=$(shell awk -F: '/^Version:/{print $$2}' < nagios-plugins-certstore.spec | awk '{print $$1}' )

test-destdir: step-test-destdir
step-test-destdir:
	#test -d "$(DESTDIR)"
	test -n "$(DESTDIR)"
	touch step-test-destdir

install-cron: step-install-cron
#step-install-cron: test-destdir nagios-plugins-certstore.cron
step-install-cron: test-destdir
	#install -m 644 -D nagios-plugins-certstore.cron $(DESTDIR)/etc/cron.d/nagios-plugins-certstore
	touch step-install-cron

install-conf: step-install-conf
#step-install-conf: test-destdir nagios-plugins-certstore.conf
step-install-conf: test-destdir
	#install -m 644 -D nagios-plugins-certstore.conf $(DESTDIR)/etc/nagios-plugins-certstore.conf
	touch step-install-conf

install-log: step-install-log
step-install-log: test-destdir
	touch step-install-log
    
install-bin: step-install-bin
#step-install-bin: test-destdir nagios-plugins-certstore.sh
step-install-bin: test-destdir
	install -D      check-certs2.sh         $(DESTDIR)/usr/lib64/nagios/plugins/check_certstore
	install -D      txt-from-jks.sh         $(DESTDIR)/usr/bin/txt-from-jks.sh
	install -D      txt-from-pem.sh         $(DESTDIR)/usr/bin/txt-from-pem.sh
	install -D      txt-from-p12.sh         $(DESTDIR)/usr/bin/txt-from-p12.sh

	touch step-install-bin

install: install-bin install-conf install-cron install-log

clean:
	rm step-* || true
	rm nagios-plugins-certstore-*.tar.gz || true
	rm -rf DESTDIR/

dist:
	git archive --format=tar --prefix="nagios-plugins-certstore-$(SPECVERSION)/" -o nagios-plugins-certstore-$(SPECVERSION).tar HEAD
	rm nagios-plugins-certstore-$(SPECVERSION).tar.gz || true
	gzip nagios-plugins-certstore-$(SPECVERSION).tar

rpm: dist
	cp nagios-plugins-certstore-$(SPECVERSION).tar.gz ~/rpmbuild/SOURCES/
	rpmbuild -bb --clean nagios-plugins-certstore.spec

deb:
	fakeroot dpkg-buildpackage -us -uc

