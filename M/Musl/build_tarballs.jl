using BinaryBuilder

name = "Musl"
version = v"1.2.3"

# sources to build, such as mingw32, our patches, etc....
sources = [
    ArchiveSource("https://www.musl-libc.org/releases/musl-$(version).tar.gz",
                  "7d5b0b6062521e4627e099e4c9dc8248d32a30285e959b7eecaa780cf8cfd4a4"),
]

# Bash recipe for building across all platforms
script = raw"""
cd ${WORKSPACE}/srcdir/musl-*

mkdir musl_build && cd musl_build

musl_arch()
{
    case "${target}" in
        i686*)
            echo i386 ;;
        arm*)
            echo armhf ;;
        *)
            echo ${target%%-*} ;;
    esac
}

export LDFLAGS="${LDFLAGS} -Wl,-soname,libc.musl-$(musl_arch).so.1"
${WORKSPACE}/srcdir/musl-*/configure --prefix=/usr \
    --build=${MACHTYPE} \
    --host=${target} \
    --disable-multilib \
    --disable-werror \
    --enable-optimize \
    --enable-debug

make -j${nproc}

# Install to fake directory
make install DESTDIR=${WORKSPACE}/srcdir/musl_deploy

# In reality, all we want is what we need to run Musl programs, so
# we just copy the dynamic loader directly over.
mkdir -p ${prefix}/lib
loader=$(echo ${WORKSPACE}/srcdir/musl_deploy/lib/*.so*)
mv ${WORKSPACE}/srcdir/musl_deploy/usr/lib/libc.so ${prefix}/lib/$(basename "${loader}")

install_license ${WORKSPACE}/srcdir/musl-*/COPYRIGHT
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = supported_platforms(; exclude=p->libc(p) != "musl")

# The products that we will ensure are always built
products = [
    LibraryProduct(["ld-musl-x86_64", "ld-musl-i386", "ld-musl-armhf", "ld-musl-aarch64"], :libc; dont_dlopen=true),
]

# Dependencies that must be installed before this package can be built
dependencies = [
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; julia_compat="1.6", skip_audit=true)
