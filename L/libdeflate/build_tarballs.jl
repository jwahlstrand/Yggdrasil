# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "libdeflate"
version = v"1.24"

# Collection of sources required to complete build
sources = [
    GitSource(
        "https://github.com/ebiggers/libdeflate",
        "96836d7d9d10e3e0d53e6edb54eb908514e336c4"
    ),
    FileSource(
        "https://github.com/phracker/MacOSX-SDKs/releases/download/10.15/MacOSX10.13.sdk.tar.xz",
        "a3a077385205039a7c6f9e2c98ecdf2a720b2a819da715e03e0630c75782c1e4"
    ),
]

# Bash recipe for building across all platforms
script = raw"""
# This requires macOS 10.13
if [[ "${target}" == x86_64-apple-darwin* ]]; then
    rm -rf /opt/${target}/${target}/sys-root/System
    tar --extract --file=${WORKSPACE}/srcdir/MacOSX10.13.sdk.tar.xz --directory="/opt/${target}/${target}/sys-root/." --strip-components=1 MacOSX10.13.sdk/System MacOSX10.13.sdk/usr
    export MACOSX_DEPLOYMENT_TARGET=10.13
fi

cd $WORKSPACE/srcdir/libdeflate
cmake -DCMAKE_INSTALL_PREFIX=$prefix -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} -DCMAKE_BUILD_TYPE=Release
make -j${nproc}
make install
install_license ${WORKSPACE}/srcdir/libdeflate/COPYING
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line

platforms = supported_platforms()

# The products that we will ensure are always built
products = [
    LibraryProduct("libdeflate", :libdeflate)
]

# Dependencies that must be installed before this package can be built
dependencies = Dependency[
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; preferred_gcc_version=v"7", julia_compat="1.6")
