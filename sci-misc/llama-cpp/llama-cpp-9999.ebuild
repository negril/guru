# Copyright 2025-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

ROCM_VERSION="6.3"
PYTHON_COMPAT=( python3_{11..14} )
DISTUTILS_USE_PEP517="poetry"
DISTUTILS_SINGLE_IMPL=1
DISTUTILS_OPTIONAL=1

TINY_LLAMAS_COMMIT="99dd1a73db5a37100bd4ae633f4cfce6560e1567"
MODELS_MOVED_COMMIT="10b4268bd9cc0f56bbb8d58f0aa699d161eb3d26"

inherit cmake cuda distutils-r1 linux-info rocm toolchain-funcs

DESCRIPTION="Port of Facebook's LLaMA model in C/C++"
HOMEPAGE="https://github.com/ggml-org/llama.cpp"

if [[ "${PV}" == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/ggml-org/llama.cpp.git"
else
	MY_PV="b${PV#0_pre}"
	SRC_URI="https://github.com/ggml-org/llama.cpp/archive/refs/tags/${MY_PV}.tar.gz -> ${P}.tar.gz"
	S="${WORKDIR}/llama.cpp-${MY_PV}"
	KEYWORDS="~amd64"
fi

SRC_URI+="
	test? (
		https://huggingface.co/ggml-org/tiny-llamas/resolve/${TINY_LLAMAS_COMMIT}/stories15M-q4_0.gguf
		-> ggml-org_models_tinyllamas_stories15M-q4_0-${TINY_LLAMAS_COMMIT}.gguf
		https://huggingface.co/ggml-org/tiny-llamas/resolve/${TINY_LLAMAS_COMMIT}/stories260K.gguf
		-> ggml-org_models_tinyllamas_stories260K-${TINY_LLAMAS_COMMIT}.gguf
		https://huggingface.co/ggml-org/models-moved/resolve/${MODELS_MOVED_COMMIT}/tinyllama-1.1b/ggml-model-f16.gguf
		-> ggml-org_models_models-ggml-model-f16-${MODELS_MOVED_COMMIT}.gguf
	)
"

LICENSE="MIT"
SLOT="0"

CPU_FLAGS=(
	cpu_flags_x86_amx_bf16
	cpu_flags_x86_amx_int8
	cpu_flags_x86_amx_tile
	cpu_flags_x86_avx
	cpu_flags_x86_avx2
	cpu_flags_x86_avx512f
	cpu_flags_x86_avx512_bf16
	cpu_flags_x86_avx512vbmi
	cpu_flags_x86_avx512_vnni
	cpu_flags_x86_avx_vnni
	cpu_flags_x86_bmi2
	cpu_flags_x86_f16c
	cpu_flags_x86_fma3
	cpu_flags_x86_sse4_2

	# riscv
	# cpu_flags_riscv_rvv
	# cpu_flags_riscv_rv_zfh
	# cpu_flags_riscv_xtheadvector

	# loong
	# cpu_flags_loong_lasx
	# cpu_flags_loong_lsx

	# s390x (z14 or later required)
	# cpu_flags_s390x_vxe
)

IUSE="blis ${CPU_FLAGS[*]} cuda curl flexiblas hip openblas opencl +openmp python test vulkan"
REQUIRED_USE="
	?? ( blis openblas flexiblas )
	python? ( ${PYTHON_REQUIRED_USE} )
"
# RDEPEND="${PYTHON_DEPS}"

EPYTEST_PLUGINS=()
distutils_enable_tests pytest

# RESTRICT="!test? ( test )"

# BDEPEND="python? ( ${BDEPEND} )"
# RDEPEND="python? ( ${RDEPEND} )"

# curl is needed for pulling models from huggingface
# numpy is used by convert_hf_to_gguf.py
CDEPEND="
	blis? (
		sci-libs/blis:=
	)
	cuda? (
		dev-util/nvidia-cuda-toolkit:=
		x11-drivers/nvidia-drivers
	)
	curl? (
		net-misc/curl:=
	)
	flexiblas? (
		sci-libs/flexiblas:=
	)
	hip? (
		>=dev-util/hip-${ROCM_VERSION}:=
		>=sci-libs/hipBLAS-${ROCM_VERSION}:=
	)
	openblas? (
		sci-libs/openblas:=
	)
	openmp? ( || (
		sys-devel/gcc:*[openmp]
		llvm-runtimes/openmp
	) )
"
DEPEND="${CDEPEND}
	dev-cpp/nlohmann_json
	opencl? ( dev-util/opencl-headers )
	vulkan? ( dev-util/vulkan-headers )
"
# 	BDEPEND="${DISTUTILS_DEPS}"
# 	RDEPEND="${PYTHON_DEPS}"
RDEPEND="${CDEPEND}
	opencl? ( virtual/opencl )
	python? (
		${PYTHON_DEPS}
		$(python_gen_cond_dep '
		dev-python/numpy[${PYTHON_USEDEP}]
		sci-ml/sentencepiece[${PYTHON_USEDEP}]
		=dev-python/protobuf-5*[${PYTHON_USEDEP}]
		')
		>=sci-ml/pytorch-2.2.0[${PYTHON_SINGLE_USEDEP}]
		=sci-ml/transformers-4*[${PYTHON_SINGLE_USEDEP}]
	)
	vulkan? ( media-libs/vulkan-loader )
"
# we set EGIT_LFS by hand
# 	python? ( ${BDEPEND} )
BDEPEND="
	media-libs/shaderc
	dev-util/patchelf
	python? (
		${BDEPEND}
		${DISTUTILS_DEPS}
	)
	test? (
		dev-vcs/git-lfs
	)
"

pkg_pretend() {
	if use amd64; then
		if use cpu_flags_x86_f16c && use cpu_flags_x86_avx2 && use cpu_flags_x86_fma3 && ! use cpu_flags_x86_bmi2; then
			ewarn
			ewarn "CPU_FLAGS_X86: bmi2 not enabled."
			ewarn "  Not building haswell runner."
			ewarn "  Not building skylakex runner."
			ewarn "  Not building icelake runner."
			ewarn "  Not building alderlake runner."
			ewarn
			if grep bmi2 /proc/cpuinfo > /dev/null; then
				ewarn "bmi2 found in /proc/cpuinfo"
				ewarn
			fi
		fi
	fi
}

pkg_setup() {
	if use hip; then
		linux-info_pkg_setup
		if linux-info_get_any_version && linux_config_exists; then
			if ! linux_chkconfig_present HSA_AMD_SVM; then
				ewarn "To use ROCm/HIP, you need to have HSA_AMD_SVM option enabled in your kernel."
			fi
		fi

	fi
}

src_unpack() {
	if [[ ${PV} == *9999* ]]; then
		git-r3_src_unpack

		if use test; then
			EGIT_REPO_URI="https://huggingface.co/ggml-org/vocabs" \
			EGIT_CHECKOUT_DIR="${S}/models/ggml-vocabs" \
			EGIT_LFS="yes" \
				git-r3_src_unpack
		fi

		if use test; then
			git-r3_fetch "https://github.com/${PN}/${PN}_extra"
			git-r3_checkout "https://github.com/${PN}/${PN}_extra" "${WORKDIR}/${PN}_extra-${PV}"
		fi
	else
		default
	fi
}

src_prepare() {
	use cuda && cuda_src_prepare

	cmake_src_prepare

	use python && distutils-r1_python_prepare_all
}

src_configure() {
	local mycmakeargs=(
		-DLLAMA_BUILD_TESTS="$(usex test)"
		-DLLAMA_BUILD_SERVER=ON
		-DGGML_CCACHE="no"
		# -DCMAKE_SKIP_BUILD_RPATH=ON
		-DGGML_NATIVE=0	# don't set march
		-DGGML_CPU_ALL_VARIANTS="no"
		-DGGML_BACKEND_DL="yes"
		-DGGML_RPC=OFF
		-DLLAMA_CURL=$(usex curl)
		-DBUILD_NUMBER="${PR}"
		-DGGML_CUDA=$(usex cuda)
		-DGGML_OPENCL=$(usex opencl)
		-DGGML_OPENMP=$(usex openmp)
		-DGGML_VULKAN=$(usex vulkan)

		# avoid clashing with whisper.cpp
		-DCMAKE_INSTALL_LIBDIR="${EPREFIX}/usr/$(get_libdir)/llama.cpp"
		-DCMAKE_INSTALL_RPATH="${EPREFIX}/usr/$(get_libdir)/llama.cpp"
	)

	# if use amd64 || use x86; then
	# 	mycmakeargs+=(
	# 		-DGGML_AMX_BF16="$(usex cpu_flags_x86_amx_bf16)"
	# 		-DGGML_AMX_INT8="$(usex cpu_flags_x86_amx_int8)"
	# 		-DGGML_AMX_TILE="$(usex cpu_flags_x86_amx_tile)"
	# 		-DGGML_AVX2="$(usex cpu_flags_x86_avx2)"
	# 		-DGGML_AVX512="$(usex cpu_flags_x86_avx512f)"
	# 		-DGGML_AVX512_BF16="$(usex cpu_flags_x86_avx512_bf16)"
	# 		-DGGML_AVX512_VBMI="$(usex cpu_flags_x86_avx512vbmi)"
	# 		-DGGML_AVX512_VNNI="$(usex cpu_flags_x86_avx512_vnni)"
	# 		-DGGML_AVX="$(usex cpu_flags_x86_avx)"
	# 		-DGGML_AVX_VNNI="$(usex cpu_flags_x86_avx_vnni)"
	# 		-DGGML_BMI2="$(usex cpu_flags_x86_bmi2)"
	# 		-DGGML_F16C="$(usex cpu_flags_x86_f16c)"
	# 		-DGGML_FMA="$(usex cpu_flags_x86_fma3)"
	# 		-DGGML_SSE42="$(usex cpu_flags_x86_sse4_2)"
	# 	)
	# fi

	# if use loong; then
	# 	mycmakeargs+=(
	# 		-DGGML_LASX="$(usex cpu_flags_loong_lasx)"
	# 		-DGGML_LSX="$(usex cpu_flags_loong_lsx)"
	# 	)
	# fi

	# if use riscv; then
	# 	mycmakeargs+=(
	# 		-DGGML_RVV="$(usex cpu_flags_riscv_rvv)"
	# 		-DGGML_RV_ZFH="$(usex cpu_flags_riscv_rv_zfh)"
	# 		-DGGML_XTHEADVECTOR="$(usex cpu_flags_riscv_xtheadvector)"
	# 	)
	# fi

	# if use s390; then
	# 	mycmakeargs+=(
	# 		-DGGML_VXE="$(usex cpu_flags_s390x_vxe)"
	# 	)
	# fi

	if tc-is-lto ; then
		mycmakeargs+=(
			-DGGML_LTO="yes"
		)
	fi

	if use openblas ; then
		mycmakeargs+=(
			# -DGENTOO_REMOVE_CMAKE_BLAS_HACK=ON
			-DGGML_BLAS=ON -DGGML_BLAS_VENDOR=OpenBLAS
		)
	fi

	if use opencl ; then
		mycmakeargs+=(
			-DGGML_OPENCL_USE_ADRENO_KERNELS=no
		)
	fi

	if use blis ; then
		mycmakeargs+=(
			-DGGML_BLAS=ON -DGGML_BLAS_VENDOR=FLAME
		)
	fi

	if use flexiblas ; then
		mycmakeargs+=(
			-DGGML_BLAS=ON -DGGML_BLAS_VENDOR=FlexiBLAS
		)
	fi

	if use cuda ; then
		local -x CUDAHOSTCXX="$(cuda_gccdir)"
		# tries to recreate dev symlinks
		cuda_add_sandbox
		addpredict "/dev/char/"
		mycmakeargs+=(
			-DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS:-all}"
		)
	fi

	if use hip; then
		rocm_use_hipcc
		mycmakeargs+=(
			-DGGML_HIP=ON -DAMDGPU_TARGETS=$(get_amdgpu_flags)
		)
	fi

	cmake_src_configure

	if use python ; then
		distutils-r1_src_configure
	fi
}

src_test() {
	if use cuda; then
		cuda_add_sandbox -w
	fi

	[[ -c /dev/udmabuf ]] && addwrite /dev/udmabuf

	ln -rs "${CMAKE_USE_DIR}/models" "${BUILD_DIR}" || die

	if use test; then
		mkdir -p "${HOME}/.cache/llama.cpp" || die
		cp \
			"${DISTDIR}/ggml-org_models_tinyllamas_stories15M-q4_0-${TINY_LLAMAS_COMMIT}.gguf" \
			"${HOME}/.cache/llama.cpp/" \
			|| die

		mkdir -p "${BUILD_DIR}/examples/eval-callback" || die
		cp \
			"${DISTDIR}/ggml-org_models_tinyllamas_stories260K-${TINY_LLAMAS_COMMIT}.gguf" \
			"${BUILD_DIR}/examples/eval-callback/" \
			|| die

		mkdir -p "${BUILD_DIR}/models/7B" || die
		cp \
			"${DISTDIR}/ggml-org_models_models-ggml-model-f16-${MODELS_MOVED_COMMIT}.gguf" \
			"${BUILD_DIR}/models/7B/" \
			|| die
	fi

	addwrite "/proc/self/mem"
	addwrite "/proc/PID/mem"

	# insert into cmake EXTRA_ARGS --offline

	local CMAKE_SKIP_TESTS=(
		 # needs network
		"^test-arg-parser$"
	)

	if use cuda && { use opencl || use vulkan; } then
		CMAKE_SKIP_TESTS+=(
			"^test-thread-safety$"
			"^test-backend-ops$"
		)
	fi

	# cmake_src_test -j1 --output-on-failure -LE curl

	if use python ; then
		distutils-r1_src_test
	fi
}

src_compile() {
	cmake_src_compile

	if use python ; then
		distutils-r1_src_compile
	fi
}

src_install() {
	cmake_src_install

	# dobin "${BUILD_DIR}/bin/rpc-server"
	# patchelf --remove-rpath "${ED}/usr/bin/rpc-server" || die

	if use test; then
		rm -v "${ED}/usr/bin/"test-* || die
	fi

	# avoid clashing with whisper.cpp
	rm -rf "${ED}/usr/include"

	if use python ; then
		distutils-r1_src_install
	fi
}
