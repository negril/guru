# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

QTMIN="6.9.1"
inherit cmake desktop xdg

DESCRIPTION="A free, open-source Monero wallet"
HOMEPAGE="https://featherwallet.org"

if [[ "${PV}" == 9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/feather-wallet/feather.git"
else
	inherit verify-sig
	SRC_URI="
		https://featherwallet.org/files/releases/source/${P}.tar.gz
		verify-sig? ( https://featherwallet.org/files/releases/source/${P}.tar.gz.asc )
	"
	KEYWORDS="~amd64"

	BDEPEND="
		verify-sig? (
			sec-keys/openpgp-keys-featherwallet
		)
	"
	VERIFY_SIG_OPENPGP_KEY_PATH="/usr/share/openpgp-keys/featherwallet.asc"
fi

# Feather is released under the terms of the BSD license, but it vendors
# code from Monero and Tor too.
LICENSE="BSD MIT"
SLOT="0"
IUSE="bounties calc crowdfunding home qrcode revuo tickers xmrig wayland"
DEPEND="
	dev-libs/libsodium:=
	media-gfx/qrencode:=
	media-gfx/zbar:=[v4l]
	~dev-libs/polyseed-1.0.0
	dev-libs/libzip:=
	dev-libs/boost:=[nls]
	>=dev-qt/qtbase-${QTMIN}:6[wayland?]
	>=dev-qt/qtsvg-${QTMIN}:6
	>=dev-qt/qtmultimedia-${QTMIN}:6
	>=dev-qt/qtwebsockets-${QTMIN}:6
	dev-libs/libgcrypt:=
	sys-libs/zlib
	dev-libs/openssl:=
	net-dns/unbound:=[threads]
	net-libs/czmq:=
	qrcode? ( media-libs/zxing-cpp )
"
RDEPEND="
	${DEPEND}
	net-vpn/tor
	xmrig? ( net-misc/xmrig )
"
BDEPEND+="
	virtual/pkgconfig
"

src_prepare() {
	if [[ "${PV}" != 9999* ]]; then
		cat > "${S}/src/config-feather.h" <<- EOF || die
			#define FEATHER_VERSION "${PV}"
			#define TOR_VERSION "NOT_EMBEDDED"
		EOF
	fi

	if ! use wayland; then
		eapply "${FILESDIR}/feather-no-wayland.patch"
	fi

	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DCMAKE_BUILD_TYPE=Release
		-DBUILD_SHARED_LIBS=OFF
		-DARCH=x86-64
		-DBUILD_TAG="linux-x64"
		-DBUILD_64=ON
		-DSELF_CONTAINED=OFF
		-DWITH_PLUGIN_HOME=$(usex home)
		-DWITH_PLUGIN_TICKERS=$(usex tickers)
		-DWITH_PLUGIN_CROWDFUNDING=$(usex crowdfunding)
		-DWITH_PLUGIN_BOUNTIES=$(usex bounties)
		-DWITH_PLUGIN_REVUO=$(usex revuo)
		-DWITH_PLUGIN_CALC=$(usex calc)
		-DWITH_PLUGIN_XMRIG=$(usex xmrig)
		-DCHECK_UPDATES=OFF
		-DPLATFORM_INSTALLER=OFF
		-DUSE_DEVICE_TREZOR=OFF
		-DDONATE_BEG=OFF
		-DWITH_SCANNER=$(usex qrcode)
	)
	cmake_src_configure
}

src_compile() {
	cmake_build feather
}

src_install() {
	dobin "${BUILD_DIR}/bin/feather"

	local res
	for res in 32 48 64 96 128 256 512 ; do
		newicon -s "${res}" "src/assets/images/appicons/${res}x${res}.png" "feather.png"
	done

	domenu "src/assets/feather.desktop"
}

pkg_postinst() {
	xdg_pkg_postinst

	einfo "Ensure that Tor is running with 'rc-service tor start' before"
	einfo "using Feather."
	einfo ""
	einfo "Donation popup has been disabled in this build."
	einfo "Consider donating to upstream developers here:"
	einfo "https://docs.featherwallet.org/guides/donate"
}
