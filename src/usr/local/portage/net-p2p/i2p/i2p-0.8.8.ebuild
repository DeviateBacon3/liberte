# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

# Based on the ebuild from zugaina overlay:
# http://gentoo-overlays.zugaina.org/zugaina/portage/net-p2p/i2p/

EAPI="4"

inherit eutils java-pkg-2 java-ant-2

JETTY_V="5.1.15"

DESCRIPTION="I2P is an anonymous network."

SRC_URI="http://mirror.i2p2.de/${PN}source_${PV}.tar.bz2
	http://dist.codehaus.org/jetty/jetty-5.1.x/jetty-${JETTY_V}.tgz"
HOMEPAGE="http://www.i2p2.de/"

SLOT="0"
KEYWORDS="x86 amd64"
LICENSE="GPL-2"
IUSE=""
DEPEND=">=virtual/jdk-1.5"
RDEPEND=">=virtual/jre-1.5
         dev-java/java-service-wrapper"

pkg_setup() {
	enewgroup i2p
	enewuser  i2p -1 -1 /var/lib/i2p i2p
	rmdir /var/lib/i2p 2>/dev/null || true
}

src_unpack() {
	unpack "i2psource_${PV}.tar.bz2"
	cp "${DISTDIR}/jetty-${JETTY_V}.tgz" -P "${S}/apps/jetty" || die
}

src_compile() {
	# Make I2P router ignore internal clock offset due to internal / external clock jumps conflict
	# Fudge factor of 90 minutes corresponds to Tor's approximate time possible error
	# sed -i 's/\<return _offset;/return 0;/'                    core/java/src/net/i2p/util/Clock.java
	# sed -i 's/\<return _alreadyChanged;/return true;/'         core/java/src/net/i2p/util/Clock.java
	# sed -i 's/\<return offset + systemNow;/return systemNow;/' router/java/src/net/i2p/router/RouterClock.java
	# sed -i 's/\( CLOCK_FUDGE_FACTOR =\) 1\*\(.*\);/\1 90*\2;/' router/java/src/net/i2p/router/Router.java

	eant pkg || die
}

src_install() {
	cd pkg-temp

	sed -i 's:[%$]INSTALL_PATH:/opt/i2p:g'              eepget i2prouter runplain.sh *.config
	sed -i 's:[%$]SYSTEM_java_io_tmpdir:/tmp:g'         runplain.sh
	sed -i 's:^\(WRAPPER_CMD=\).*:\1/usr/bin/wrapper:'  i2prouter

	sed -i 's:^#\?PIDDIR=.*:PIDDIR="/var/run/":g'       i2prouter
	sed -i 's:[%$]SYSTEM_java_io_tmpdir:/var/run/i2p:g' i2prouter *.config

# 	Install to package root
	exeinto /opt/i2p
	insinto /opt/i2p

# 	Install files
	doins ${S}/apps/i2psnark/jetty-i2psnark.xml ${S}/pkg-temp/blocklist.txt ${S}/apps/i2psnark/launch-i2psnark ${S}/pkg-temp/hosts.txt *.config || die
	doexe eepget i2prouter ${S}/apps/i2psnark/launch-i2psnark runplain.sh || die
	dodoc history.txt LICENSE.txt INSTALL-headless.txt
	doman man/*

# 	Install dirs
	doins -r docs geoip eepsite scripts certificates webapps
	dodoc -r licenses

# 	Install files to package lib
	insinto /opt/i2p/lib
	exeinto /opt/i2p/lib
	find lib/ -maxdepth 1 -type f ! -name '*.dll' ! -name wrapper.jar ! -name jbigi.jar -print0 | xargs -0 doins || die

	dosym "${D}"/opt/i2p/i2prouter /usr/bin/i2prouter
	dosym "${D}"/opt/i2p/eepget    /usr/bin/eepget

	doinitd "${FILESDIR}"/i2p

	keepdir         /var/lib/i2p /var/run/i2p /var/log/i2p
	fperms  750     /var/lib/i2p /var/run/i2p /var/log/i2p
	fowners i2p:i2p /var/lib/i2p /var/run/i2p /var/log/i2p
}

pkg_postinst() {
	einfo "Configure the router now : http://localhost:7657/index.jsp"
	einfo "Use /etc/init.d/i2p start to start I2P"
}