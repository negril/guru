# Copyright 2021-2025 Haelwenn (lanodan) Monnier <contact@hacktivis.me>
# Distributed under the terms of the GNU General Public License v2

EAPI=8

MY_TEST_V="0.10"

if [[ "${PV}" == 9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://anongit.hacktivis.me/git/deblob.git"
else
	VERIFY_SIG_METHOD=signify
	inherit verify-sig

	SRC_URI="
		https://distfiles.hacktivis.me/releases/deblob/${P}.tar.gz
		test? ( https://distfiles.hacktivis.me/releases/deblob-test/deblob-test-${MY_TEST_V}.tar.gz )
		verify-sig? (
			https://distfiles.hacktivis.me/releases/deblob/${P}.tar.gz.sign
			test? ( https://distfiles.hacktivis.me/releases/deblob-test/deblob-test-${MY_TEST_V}.tar.gz.sign )
		)
	"
	KEYWORDS="~amd64 ~arm64 ~riscv"

	SIG_PN="signify-keys-lanodan"
	SIG_PV="2025"
	BDEPEND="
		verify-sig? (
			sec-keys/${SIG_PN}:${SIG_PV}
		)
	"
fi

DESCRIPTION="remove binary executables from a directory"
# permalink
HOMEPAGE="https://hacktivis.me/projects/deblob"
LICENSE="BSD"
SLOT="0"

IUSE="test"

RESTRICT="!test? ( test )"

DEPEND="
	>=dev-lang/hare-0.25.2:=
	>=dev-hare/hare-json-0.25.2.0
"

# built by hare
QA_FLAGS_IGNORED="usr/bin/deblob"

src_unpack() {
	if use verify-sig && [[ "${PV}" != 9999* ]]; then
		# Too many levels of symbolic links
		cd "${DISTDIR}" || die
		cp ${A} "${WORKDIR}" || die
		cd "${WORKDIR}" || die

		local VERIFY_SIG_OPENPGP_KEY_PATH="/usr/share/signify-keys/${SIG_PN}-${SIG_PV}.pub"
		verify-sig_verify_detached "${P}.tar.gz" "${P}.tar.gz.sign"
		use test && verify-sig_verify_detached "deblob-test-${MY_TEST_V}.tar.gz" "deblob-test-${MY_TEST_V}.tar.gz.sign"
	fi

	default

	if use test && [[ "${PV}" != 9999* ]]; then
		rm -r "${S}/test" || die
		mv "${WORKDIR}/deblob-test-${MY_TEST_V}" "${S}/test" || die
	fi
}

src_install() {
	PREFIX="${EPREFIX}/usr" default
}
