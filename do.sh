#! /bin/bash

# set the unnoficial strict mode in bash
set -euo pipefail
IFS=$'\n\t'

CHAIN_PATH=/opt/M64/mips64chain

# toolchain build path
BUILD_PATH="${BUILD_PATH:-build}"

# defines the build system variables to allow cross compilation.
MIPS64_BUILD=${MIPS64_BUILD:-""}
MIPS64_HOST=${MIPS64_HOST:-""}
MIPS64_TARGET=${MIPS64_TARGET:-mips64-}

# set CHAIN_PATH before calling the script to change the default installation directory path
#INSTALL_PATH="${CHAIN_PATH}"
INSTALL_PATH=$CHAIN_PATH
# set PATH for newlib to compile using GCC for MIPS MIPS64 (pass 1)
export PATH="$PATH:$INSTALL_PATH/bin"

# determine job distribution count between cpu cores
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN)}"
JOBS="${JOBS:-1}" # if getconf returned nothing, default to 1

# GCC configure arguments to use system GMP/MPC/MFPF
GCC_CONFIGURE_ARGS=()

# dep versions
BINUTILS_V=2.41
GCC_V=13.2.0
NEWLIB_V=4.3.0.20230120
GMP_V=6.3.0 
MPC_V=1.3.1 
MPFR_V=4.2.0
MAKE_V=${MAKE_V:-""}

# define ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
RESET='\033[0m'

# check if a command-line tool is available: status 0 means "yes"; status 1 means "no"
IsInstalled () 
{
    (command -v "$1" >/dev/null 2>&1)
    return $?
}

# check if a certain folder exists in the fs: status 0 means "yes"; status 1 means "no"
IsLibAvail () 
{
    folder_path="$1"

    if [ -d "$folder_path" ]; then
        return 0
    else
        return 1 
    fi
}

if ! IsInstalled brew; then
    echo -e "\n${RED}You don't have brew installed!${RESET}\n"
    echo -e "Homebrew is needed to download dependencies for compiling the toolchain, you can get it here: ${GREEN}https://brew.sh${RESET}\n"
    exit 1
fi

# install dependencies automatically if not already installed
if ! IsInstalled wget; then
    brew install -q wget
elif ! IsLibAvail "/opt/homebrew/Cellar/gmp"; then
    brew install -q gmp
elif ! IsLibAvail "/opt/homebrew/Cellar/mpfr"; then
    brew install -q mpfr
elif ! IsLibAvail "/opt/homebrew/Cellar/libmpc"; then
    brew install -q libmpc
elif ! IsLibAvail "/opt/homebrew/Cellar/gnu-sed"; then
    brew install -q gsed
elif ! IsInstalled makeinfo; then
    brew install -q texinfo
else
    echo -e "${GREEN}All the dependencies are installed in your system."
fi
exit 1
# FIXME: we could avoid download/symlink GMP and friends for a cross-compiler
# but we need to symlink them for the canadian compiler.
#GMP_V=""
#MPC_V=""
#MPFR_V=""
# Tell GCC configure where to find the dependent libraries
GCC_CONFIGURE_ARGS=(
    "--with-gmp=$(brew --prefix)"
    "--with-mpfr=$(brew --prefix)"
    "--with-mpc=$(brew --prefix)"
)

# Install GNU sed as default sed in PATH. GCC compilation fails otherwise,
# because it does not work with BSD sed.
PATH="$(brew --prefix gsed)/libexec/gnubin:$PATH"
export PATH

# Create build path and enter it
mkdir -p "$BUILD_PATH"
cd "$BUILD_PATH"

# Dependency downloads and unpack
test -f "binutils-$BINUTILS_V.tar.gz" || wget -c "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_V.tar.gz"
test -d "binutils-$BINUTILS_V"        || tar -xzf "binutils-$BINUTILS_V.tar.gz"

test -f "gcc-$GCC_V.tar.gz"           || wget -c "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_V/gcc-$GCC_V.tar.gz"
test -d "gcc-$GCC_V"                  || tar -xzf "gcc-$GCC_V.tar.gz"

test -f "newlib-$NEWLIB_V.tar.gz"     || wget -c "https://sourceware.org/pub/newlib/newlib-$NEWLIB_V.tar.gz"
test -d "newlib-$NEWLIB_V"            || tar -xzf "newlib-$NEWLIB_V.tar.gz"

if [ "$GMP_V" != "" ]; then
    test -f "gmp-$GMP_V.tar.bz2"           || wget -c "https://ftp.gnu.org/gnu/gmp/gmp-$GMP_V.tar.bz2"
    test -d "gmp-$GMP_V"                  || tar -xf "gmp-$GMP_V.tar.bz2" # note: no .gz wget -c file currently available
    pushd "gcc-$GCC_V"
    ln -sf ../"gmp-$GMP_V" "gmp"
    popd
fi

if [ "$MPC_V" != "" ]; then
    test -f "mpc-$MPC_V.tar.gz"           || wget -c "https://ftp.gnu.org/gnu/mpc/mpc-$MPC_V.tar.gz"
    test -d "mpc-$MPC_V"                  || tar -xzf "mpc-$MPC_V.tar.gz"
    pushd "gcc-$GCC_V"
    ln -sf ../"mpc-$MPC_V" "mpc"
    popd
fi

if [ "$MPFR_V" != "" ]; then
    test -f "mpfr-$MPFR_V.tar.gz"         || wget -c "https://ftp.gnu.org/gnu/mpfr/mpfr-$MPFR_V.tar.gz"
    test -d "mpfr-$MPFR_V"                || tar -xzf "mpfr-$MPFR_V.tar.gz"
    pushd "gcc-$GCC_V"
    ln -sf ../"mpfr-$MPFR_V" "mpfr"
    popd
fi

if [ "$MAKE_V" != "" ]; then
    test -f "make-$MAKE_V.tar.gz"       || wget -c "https://ftp.gnu.org/gnu/make/make-$MAKE_V.tar.gz"
    test -d "make-$MAKE_V"              || tar -xzf "make-$MAKE_V.tar.gz"
fi

# Deduce build triplet using config.guess (if not specified)
# This is by the definition the current system so it should be OK.
if [ "$MIPS64_BUILD" == "" ]; then
    MIPS64_BUILD=$("binutils-$BINUTILS_V"/config.guess)
fi

if [ "$MIPS64_HOST" == "" ]; then
    MIPS64_HOST="$MIPS64_BUILD"
fi


if [ "$MIPS64_BUILD" == "$MIPS64_HOST" ]; then
    # Standard cross.
    CROSS_PREFIX=$INSTALL_PATH
else
    # Canadian cross.
    # The standard BUILD->TARGET cross-compiler will be installed into a separate prefix, as it is not
    # part of the distribution.
    mkdir -p cross_prefix
    CROSS_PREFIX="$(cd "$(dirname -- "cross_prefix")" >/dev/null; pwd -P)/$(basename -- "cross_prefix")"
    PATH="$CROSS_PREFIX/bin:$PATH"
    export PATH

    # Instead, the HOST->TARGET cross-compiler can be installed into the final installation path
    CANADIAN_PREFIX=$INSTALL_PATH

    # We need to build a canadian toolchain.
    # First we need a host compiler, that is binutils+gcc targeting the host. For instance,
    # when building a Libdragon Windows toolchain from Linux, this would be x86_64-w64-ming32,
    # that is, a compiler that we run that generates Windows executables.
    # Check if a host compiler is available. If so, we can just skip this step.
    if IsInstalled "$MIPS64_HOST"-gcc; then
        echo Found host compiler: "$MIPS64_HOST"-gcc in PATH. Using it.
    else
        if [ "$MIPS64_HOST" == "x86_64-w64-mingw32" ]; then
            echo This script requires a working Windows cross-compiler.
            echo We could build it for you, but it would make the process even longer.
            echo Install it instead:
            echo "  * Linux (Debian/Ubuntu): apt install mingw-w64"
            echo "  * macOS: brew install mingw-w64"
            exit 1
        else
            echo "Unimplemented option: we support building a Windows toolchain only, for now."
        fi
    fi
fi

# Compile BUILD->TARGET binutils
mkdir -p binutils_compile_target
pushd binutils_compile_target
../"binutils-$BINUTILS_V"/configure \
    --prefix="$CROSS_PREFIX" \
    --target="$MIPS64_TARGET" \
    --with-cpu=mips64vr4300 \
    --disable-werror
make -j "$JOBS"
make install-strip || sudo make install-strip || su -c "make install-strip"
popd

# Compile GCC for MIPS MIPS64.
# We need to build the C++ compiler to build the target libstd++ later.
mkdir -p gcc_compile_target
pushd gcc_compile_target
../"gcc-$GCC_V"/configure "${GCC_CONFIGURE_ARGS[@]}" \
    --prefix="$CROSS_PREFIX" \
    --target="$MIPS64_TARGET" \
    --with-arch=vr4300 \
    --with-tune=vr4300 \
    --enable-languages=c,c++ \
    --without-headers \
    --disable-libssp \
    --enable-multilib \
    --disable-shared \
    --with-gcc \
    --with-newlib \
    --disable-threads \
    --disable-win32-registry \
    --disable-nls \
    --disable-werror \
    --with-system-zlib
make all-gcc -j "$JOBS"
make install-gcc || sudo make install-gcc || su -c "make install-gcc"
make all-target-libgcc -j "$JOBS"
make install-target-libgcc || sudo make install-target-libgcc || su -c "make install-target-libgcc"
popd

# Compile newlib for target.
mkdir -p newlib_compile_target
pushd newlib_compile_target
CFLAGS_FOR_TARGET="-DHAVE_ASSERT_FUNC -O2" ../"newlib-$NEWLIB_V"/configure \
    --prefix="$CROSS_PREFIX" \
    --target="$MIPS64_TARGET" \
    --with-cpu=mips64vr4300 \
    --disable-threads \
    --disable-libssp \
    --disable-werror
make -j "$JOBS"
make install || sudo env PATH="$PATH" make install || su -c "env PATH=\"$PATH\" make install"
popd

# For a standard cross-compiler, the only thing left is to finish compiling the target libraries
# like libstd++. We can continue on the previous GCC build target.
if [ "$MIPS64_BUILD" == "$MIPS64_HOST" ]; then
    pushd gcc_compile_target
    make all -j "$JOBS"
    make install-strip || sudo make install-strip || su -c "make install-strip"
    popd
else
    # Compile HOST->TARGET binutils
    # NOTE: we pass --without-msgpack to workaround a bug in Binutils, introduced
    # with this commit: https://sourceware.org/git/?p=binutils-gdb.git;a=commit;h=2952f10cd79af4645222f124f28c7928287d8113
    # This is due to the fact that pkg-config is used to activate compilation with msgpack
    # but that it is not correct in the case of a canadian cross.
    echo "Compiling binutils-$BINUTILS_V for foreign host"
    mkdir -p binutils_compile_host
    pushd binutils_compile_host
    ../"binutils-$BINUTILS_V"/configure \
        --prefix="$INSTALL_PATH" \
        --build="$MIPS64_BUILD" \
        --host="$MIPS64_HOST" \
        --target="$MIPS64_TARGET" \
        --disable-werror \
        --without-msgpack
    make -j "$JOBS"
    make install-strip || sudo make install-strip || su -c "make install-strip"
    popd

    # Compile HOST->TARGET gcc
    mkdir -p gcc_compile
    pushd gcc_compile
    CFLAGS_FOR_TARGET="-O2" CXXFLAGS_FOR_TARGET="-O2" \
        ../"gcc-$GCC_V"/configure \
        --prefix="$INSTALL_PATH" \
        --target="$MIPS64_TARGET" \
        --build="$MIPS64_BUILD" \
        --host="$MIPS64_HOST" \
        --disable-werror \
        --with-arch=vr4300 \
        --with-tune=vr4300 \
        --enable-languages=c,c++ \
        --with-newlib \
        --enable-multilib \
        --with-gcc \
        --disable-libssp \
        --disable-shared \
        --disable-threads \
        --disable-win32-registry \
        --disable-nls
    make all-target-libgcc -j "$JOBS"
    make install-target-libgcc || sudo make install-target-libgcc || su -c "make install-target-libgcc"
    popd

    # Compile newlib for target.
    mkdir -p newlib_compile
    pushd newlib_compile
    CFLAGS_FOR_TARGET="-DHAVE_ASSERT_FUNC -O2" ../"newlib-$NEWLIB_V"/configure \
        --prefix="$INSTALL_PATH" \
        --target="$MIPS64_TARGET" \
        --with-cpu=mips64vr4300 \
        --disable-threads \
        --disable-libssp \
        --disable-werror
    make -j "$JOBS"
    make install || sudo env PATH="$PATH" make install || su -c "env PATH=\"$PATH\" make install"
    popd

    # Finish compiling GCC
    mkdir -p gcc_compile
    pushd gcc_compile
    make all -j "$JOBS"
    make install-strip || sudo make install-strip || su -c "make install-strip"
    popd
fi

if [ "$MAKE_V" != "" ]; then
    pushd "make-$MAKE_V"
    ./configure \
      --prefix="$INSTALL_PATH" \
        --disable-largefile \
        --disable-nls \
        --disable-rpath \
        --build="$MIPS64_BUILD" \
        --host="$MIPS64_HOST"
    make -j "$JOBS"
    make install-strip || sudo make install-strip || su -c "make install-strip"
    popd
fi

# Final message
echo
echo "***********************************************"
echo "Libdragon toolchain correctly built and installed"
echo "Installation directory: \"${CHAIN_PATH}\""
echo "Build directory: \"${BUILD_PATH}\" (can be removed now)"
