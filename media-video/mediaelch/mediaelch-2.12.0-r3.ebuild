# Copyright 2021-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic toolchain-funcs

DESCRIPTION="Video metadata scraper"
HOMEPAGE="https://www.mediaelch.de/"

MY_PN="MediaElch"

if [[ ${PV} == *9999 ]] ; then
	EGIT_REPO_URI="https://github.com/Komet/${MY_PN}"
	EGIT_BRANCH="master"
	EGIT_SUBMODULES=()
	inherit git-r3
else
	RESTRICT="mirror"
	SRC_URI="https://github.com/Komet/${MY_PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64"
	S="${WORKDIR}/${MY_PN}-${PV}"
fi

LICENSE="LGPL-3"
SLOT="0"
IUSE="debug"

DEPEND="
	dev-libs/quazip
	dev-qt/qt5compat:6
	dev-qt/qtbase:6[concurrent,gui,opengl,sql,widgets,xml]
	dev-qt/qtdeclarative:6
	dev-qt/qtmultimedia:6
	dev-qt/qtsvg:6
	dev-qt/qttools:6
	media-video/ffmpeg
	media-video/mediainfo
	x11-libs/libxkbcommon
"

RDEPEND="${DEPEND}"

PATCHES=(
	"${FILESDIR}/2.12.0-1878.patch"
	"${FILESDIR}/2.12.0-1995.patch"
)

src_configure() {
	local mycmakeargs=(
		"-DUSE_EXTERN_QUAZIP=ON"
		"-DDISABLE_UPDATER=ON"
		"-DMEDIAELCH_FORCE_QT6=ON"
		"-DENABLE_LTO=$(tc-is-lto)"
	)

	if use debug; then
		local CMAKE_BUILD_TYPE=Debug
		mycmakeargs+=("-DSANITIZE_ADDRESS=on")
		append-cxxflags "-fsanitize=address"
	fi

	cmake_src_configure
}
