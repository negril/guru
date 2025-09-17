# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit java-pkg-2 systemd

MAJOR_PV="$(ver_cut 1-2)"
REL_PV="$(ver_cut 3)"
COMMIT="59c0cb0f3"

DESCRIPTION="YaCy - p2p based distributed web-search engine"
HOMEPAGE="https://www.yacy.net/"
SRC_URI="https://download.yacy.net/yacy_v${MAJOR_PV}_${REL_PV}_${COMMIT}.tar.gz"

S="${WORKDIR}/${PN}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"

DEPEND="
	>=virtual/jdk-1.8
	acct-group/${PN}
	acct-user/${PN}
"
RDEPEND="${DEPEND}"

EANT_BUILD_TARGET="all"
UNINSTALL_IGNORE="/usr/share/${PN}/DATA"

src_install() {
	# remove win-only stuff
	find "${S}" -name "*.bat" -exec rm '{}' \; || die
	# remove init-scripts
	rm "${S}"/*.sh || die
	# remove sources
	rm -r "${S}/source" || die
	rm "${S}/build.properties" "${S}/build.xml" || die

	rm -r "${S}"/lib/*License || die

	dodoc AUTHORS NOTICE
	rm AUTHORS NOTICE COPYRIGHT gpl.txt || die

	local yacy_home="/usr/share/${PN}"
	dodir "${yacy_home}"

	insinto "${yacy_home}"
	doins -r "${S}"/*

	dodir "/var/log/${PN}"
	fowners "${PN}":"${PN}" "/var/log/${PN}"
	keepdir "/var/log/${PN}"

	dosym -r "/var/lib/${PN}" "${yacy_home}/DATA"

	exeinto /etc/init.d
	newexe "${FILESDIR}/${PN}.rc" "${PN}"
	doconfd "${FILESDIR}/${PN}.confd"

	systemd_newunit "${FILESDIR}/${PN}-ipv6.service" "${PN}.service"
}

pkg_postinst() {
	einfo "${PN}.logging will write logfiles into ${EPREFIX}/var/lib/${PN}/LOG"
	einfo "To setup YaCy, open http://localhost:8090 in your browser."
}
