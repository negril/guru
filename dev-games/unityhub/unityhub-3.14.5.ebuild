# Copyright 2022-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit unpacker xdg
# TODO 2a
# inherit wrapper

DESCRIPTION="Official Unity tool for managing Unity Engines and projects"
HOMEPAGE="https://unity.com"
SRC_URI="
	amd64? (
		elibc_glibc? (
			https://hub.unity3d.com/linux/repos/deb/pool/main/u/unity/unityhub_amd64/${PN}-amd64-${PV}.deb
		)
	)
"
S="${WORKDIR}"

LICENSE="Unity-TOS"
SLOT="0"
KEYWORDS="-* ~amd64"

IUSE="+system-libs +system-ffmpeg"

RESTRICT="bindist mirror strip test"

RDEPEND="
	app-accessibility/at-spi2-core:2
	app-alternatives/cpio
	|| (
		>=app-arch/7zip-24.09[symlink(+)]
		app-arch/p7zip
	)
	app-crypt/libsecret
	dev-libs/nspr
	dev-libs/nss
	|| (
		dev-util/lttng-ust-compat:0/2.12
		dev-util/lttng-ust:0/2.12
	)
	media-libs/alsa-lib
	media-libs/mesa
	net-print/cups
	sys-apps/dbus
	|| (
		sys-apps/systemd
		sys-apps/systemd-utils
	)
	sys-libs/glibc
	x11-libs/gtk+:3
	x11-libs/libX11
	x11-libs/libxcb
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libxkbcommon
	x11-libs/libXrandr
	system-ffmpeg? (
		media-video/ffmpeg[chromium(-)]
	)
	!system-libs? (
		sys-apps/util-linux
	)
	system-libs? (
		media-libs/libglvnd[X]
		media-libs/vulkan-loader

		dev-libs/expat
		dev-libs/glib:2
		gnome-base/librsvg:2
		media-libs/freetype
		media-libs/giflib
		media-libs/harfbuzz
		media-libs/libjpeg-turbo
		media-libs/libpng
		x11-libs/cairo
		x11-libs/gdk-pixbuf:2
		x11-libs/pango
		x11-libs/pixman
		virtual/zlib
	)
"

PATCHES=(
	"${FILESDIR}/unityhub-3.14.5-fix-SCRIPT_DIR-lookup.patch"
)

QA_PREBUILT="opt/${PN}"

pkg_pretend() {
	if ! use elibc_glibc; then
		die
	fi
}

src_install() {
	pushd "./opt/${PN}" &> /dev/null || die

	# bundled 7z
	rm -r ./resources/app.asar.unpacked/lib || die

	if use system-libs; then
		local SYSTEM_LIBS=(
			libEGL.so
			libGLESv2.so
			libvulkan.so.1
		)

		rm "${SYSTEM_LIBS[@]}" || die

		# TODO 1 makes lookup faster?
		local lib
		for lib in "${SYSTEM_LIBS[@]}"; do
			ln -sn "${ESYSROOT:-}/usr/$(get_libdir)/${lib}" "${lib}" || die
		done

		rm resources/app.asar.unpacked/node_modules/*/build/Release/*.so* || die
	fi

	if use system-ffmpeg; then
		rm libffmpeg.so || die
		# TODO 2b
		ln -sn "${ESYSROOT}/usr/$(get_libdir)/chromium/libffmpeg.so" "libffmpeg.so" || die
	fi

	popd &> /dev/null || die

	mv usr/share/doc/{"${PN}","${P?}"} || die
	mv ./* "${ED?}/" || die

	# # TODO 2a
	# sed \
	# 	-e "s#/opt/unityhub/#${EPREFIX}/opt/bin/#" \
	# 	-i "${ED}/usr/share/applications/unityhub.desktop" \
	# 	|| die

	# make_wrapper unityhub \
	# 	/opt/unityhub/unityhub \
	# 	"" \
	# 	"${ESYSROOT}/usr/$(get_libdir):${ESYSROOT}/usr/$(get_libdir)/chromium" \
	# 	/opt/bin

	# TODO 2b
	dodir opt/bin
	dosym -r /opt/unityhub/unityhub /opt/bin/unityhub

	docompress -x "/usr/share/doc/${P}/changelog.gz"
}
