# Copyright 2025 Haelwenn (lanodan) Monnier <contact@hacktivis.me>
# Distributed under the terms of the GNU General Public License v2

EAPI=8

if [[ "${PV}" == 9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://anongit.hacktivis.me/git/cmd-timer.git"
else
	VERIFY_SIG_METHOD="signify"
	inherit verify-sig

	SRC_URI="
		https://distfiles.hacktivis.me/releases/cmd-timer/${P}.tar.gz
		verify-sig? (
			https://distfiles.hacktivis.me/releases/cmd-timer/${P}.tar.gz.sign
		)
	"

	KEYWORDS="~amd64 ~arm64"

	SIG_PN="signify-keys-lanodan"
	SIG_PV="2025"
	BDEPEND="
		verify-sig? (
			sec-keys/${SIG_PN}:${SIG_PV}
		)
	"
fi

DESCRIPTION="run command at a specific interval"
HOMEPAGE="https://hacktivis.me/git/cmd-timer/"
LICENSE="MPL-2.0"
SLOT="0"

IUSE="static"

src_unpack() {
	default

	if use verify-sig && [[ "${PV}" != 9999* ]]; then
		# Too many levels of symbolic links
		cd "${DISTDIR}" || die
		# NOTE You don't need to copy everything in ${A} to WORKDIR
		cp ${A} "${WORKDIR}" || die
		cd "${WORKDIR}" || die

		local VERIFY_SIG_OPENPGP_KEY_PATH="/usr/share/signify-keys/${SIG_PN}-${SIG_PV}.pub"
		verify-sig_verify_detached "${P}.tar.gz" "${P}.tar.gz.sign"

		unpack "${P}.tar.gz"
		rm "${P}.tar.gz"
	fi
}

src_compile() {
	emake $(usev static-libs LDSTATIC="-static")
}

src_install() {
	emake install DESTDIR="${D}" PREFIX="${EPEFIX}/usr"
}
