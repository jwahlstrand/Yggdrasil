# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg
using Base.BinaryPlatforms

# needed for libjulia_platforms and julia_versions
include("../../L/libjulia/common.jl")
# we only support julia >=1.10
filter!(>=(v"1.10"), julia_versions)

# See https://github.com/JuliaLang/Pkg.jl/issues/2942
# Once this Pkg issue is resolved, this must be removed
# without this binarybuilder tries to install libblastrampoline 3.0.4 for all julia targets
uuidblastramp = Base.UUID("8e850b90-86db-534c-a0d3-1478176c7d93")
delete!.(Pkg.Types.get_last_stdlibs.(julia_versions), uuidblastramp)

uuidopenssl = Base.UUID("458c3c95-2e84-50aa-8efc-19380b2a3a95")
delete!(Pkg.Types.get_last_stdlibs(v"1.12.0"), uuidopenssl)
delete!(Pkg.Types.get_last_stdlibs(v"1.13.0"), uuidopenssl)

name = "libpolymake_julia"
version = v"0.14.0"

# reminder: change the above version when changing the supported julia versions
# julia_versions is now taken from libjulia/common.jl and filtered
julia_compat = join("~" .* string.(getfield.(julia_versions, :major)) .* "." .* string.(getfield.(julia_versions, :minor)), ", ")

# Collection of sources required to build libpolymake_julia
sources = [
    GitSource("https://github.com/oscar-system/libpolymake-julia.git",
              "ab7ba5a059a7cb08ce2875fc291219b5b20ac08e"),
]

# Bash recipe for building across all platforms
script = raw"""
# remove default perl which interferes with the hostbuild perl
rm -f /usr/bin/perl

cmake libpolymake-j*/ -B build \
   -DJulia_PREFIX="$prefix" \
   -DCMAKE_INSTALL_PREFIX="$prefix" \
   -DCMAKE_FIND_ROOT_PATH="$prefix" \
   -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TARGET_TOOLCHAIN}" \
   -DCMAKE_BUILD_TYPE=Release

VERBOSE=ON cmake --build build --config Release --target install -- -j${nproc}

install_license libpolymake-j*/LICENSE.md

jsondir=${prefix}/share/libpolymake_julia/appsjson/
mkdir -p $jsondir
$host_bindir/perl $host_bindir/polymake --iscript libpolymake-j*/src/polymake/apptojson.pl $jsondir
"""


platforms = vcat(libjulia_platforms.(julia_versions)...)
filter!(p -> !Sys.iswindows(p) && arch(p) != "armv6l", platforms)
filter!(p -> !(Sys.isfreebsd(p) && arch(p) == "aarch64"), platforms)
filter!(p -> arch(p) != "riscv64", platforms) # filter riscv64 until supported by all dependencies
platforms = expand_cxxstring_abis(platforms)

# The products that we will ensure are always built
products = [
    LibraryProduct("libpolymake_julia", :libpolymake_julia),
    FileProduct("share/libpolymake_julia/type_translator.jl", :type_translator),
    FileProduct("share/libpolymake_julia/generate_deps_tree.jl", :generate_deps_tree),
    FileProduct("share/libpolymake_julia/appsjson", :appsjson),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    BuildDependency(PackageSpec(;name="libjulia_jll", version=v"1.10.19")),
    BuildDependency("GMP_jll"),
    BuildDependency("MPFR_jll"),
    # this version matches the one in Ipopt_jll (needed by polymake -> SCIP)
    BuildDependency(PackageSpec(;name="libblastrampoline_jll", version = v"5.4.0")),
    Dependency("CompilerSupportLibraries_jll"),
    Dependency("FLINT_jll", compat = "~301.300.0"),
    Dependency("TOPCOM_jll"; compat = "~0.17.8"),
    Dependency("lib4ti2_jll"; compat = "^1.6.10"),
    Dependency("libcxxwrap_julia_jll"; compat = "~0.14.3"),
    Dependency("polymake_jll"; compat = "~400.1400.0"),

    HostBuildDependency(PackageSpec(name="Perl_jll", version=v"5.34.1")),
    HostBuildDependency(PackageSpec(name="polymake_jll", version=v"400.1400.0")),
    HostBuildDependency(PackageSpec(name="lib4ti2_jll", version=v"1.6.10")),
    HostBuildDependency(PackageSpec(name="TOPCOM_jll", version=v"0.17.8")),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
    preferred_gcc_version=v"8",
    clang_use_lld=false,
    julia_compat = julia_compat)

# rebuild trigger: 1
