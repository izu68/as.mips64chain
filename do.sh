#! /bin/bash

#####################################################################
#                                                                   #
#               🍎.MIPS64CHAIN - INSTALLATION SCRIPT                #
#                              by izu                               #
#                                                                   #
#           based on libdragon/tools/build-toolchain.sh             #
#                                                                   #
#####################################################################

# set the unnoficial strict mode in bash
set -euo pipefail
IFS=$'\n\t'

CHAIN_PATH=/opt/M64/mips64chain

# toolchain build path
BUILD_PATH="${BUILD_PATH:-build}"

# defines the build system variables to allow cross compilation.
MIPS64_BUILD=${MIPS64_BUILD:-""}
MIPS64_HOST=${MIPS64_HOST:-""}
MIPS64_TARGET=${MIPS64_TARGET:-mips64}

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
function IsInstalled () 
{
    (command -v "$1" >/dev/null 2>&1)
    return $?
}

# check if a certain folder exists in the fs: status 0 means "yes"; status 1 means "no"
function IsLibAvail () 
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

function Prepare ()
{
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
    elif ! IsInstalled make; then
        brew install -q make
    else
        echo -e "${GREEN}All the dependencies are installed in your system.${RESET}"
    fi

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

    echo -e "\n⬇️ ${GREEN} Now downloading and unpacking BINUTILS, GCC and NEWLIB.${RESET}\n"

    # Dependency downloads and unpack
    test -f "binutils-$BINUTILS_V.tar.gz" || wget -c "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_V.tar.gz"
    test -d "binutils-$BINUTILS_V"        || tar -xzf "binutils-$BINUTILS_V.tar.gz"

    test -f "gcc-$GCC_V.tar.gz"           || wget -c "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_V/gcc-$GCC_V.tar.gz"
    test -d "gcc-$GCC_V"                  || tar -xzf "gcc-$GCC_V.tar.gz"

    test -f "newlib-$NEWLIB_V.tar.gz"     || wget -c "https://sourceware.org/pub/newlib/newlib-$NEWLIB_V.tar.gz"
    test -d "newlib-$NEWLIB_V"            || tar -xzf "newlib-$NEWLIB_V.tar.gz"

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
        fi
    fi
}

function PrepBinutils ()
{
    # Compile BUILD->TARGET binutils
    mkdir -p binutils_compile_target
    pushd binutils_compile_target
    ../"binutils-$BINUTILS_V"/configure \
        --prefix="$CROSS_PREFIX" \
        --target="$MIPS64_TARGET" \
        --with-cpu=mips64vr4300 \
        --disable-werror
}
function CompBinutils ()
{
    make -j "$JOBS"
    make install-strip || sudo make install-strip || su -c "make install-strip"
    popd
}

function PrepGCC ()
{
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
}
function CompGCC ()
{
    make all-gcc -j "$JOBS"
    make install-gcc || sudo make install-gcc || su -c "make install-gcc"
    make all-target-libgcc -j "$JOBS"
    make install-target-libgcc || sudo make install-target-libgcc || su -c "make install-target-libgcc"
    popd
}

function PrepNewlib ()
{
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
}
function CompNewlib ()
{
    make -j "$JOBS"
    make install || sudo env PATH="$PATH" make install || su -c "env PATH=\"$PATH\" make install"
    popd
}

function CompTLibs ()
{
    # For a standard cross-compiler, the only thing left is to finish compiling the target libraries
    # like libstd++. We can continue on the previous GCC build target.
    if [ "$MIPS64_BUILD" == "$MIPS64_HOST" ]; then
        pushd gcc_compile_target
        make all -j "$JOBS"
        make install-strip || sudo make install-strip || su -c "make install-strip"
        popd
    fi
}

function Compile ()
{
    echo -e "\n📦 ${PURPLE}Preparing Binutils for compilation. This will only take a moment.${RESET}"
    PrepBinutils > /dev/null 2>&1
    echo -e "${GREEN}Now compiling and installing Binutils This may take some time. \n${YELLOW}You may need to enter your sudo password in a moment.${RESET}"
    CompBinutils > /dev/null 2>&1

    echo -e "\n📦 ${PURPLE}Preparing GCC for compilation. This may take some time.${RESET}"
    PrepGCC > /dev/null 2>&1
    echo -e "${GREEN}Now compiling and installing GCC. This will take a significant amount of time."
    CompGCC > /dev/null 2>&1

    echo -e "\n📦 ${PURPLE}Preparing Newlib for compilation. This will only take a moment.${RESET}"
    PrepBinutils > /dev/null 2>&1
    echo -e "${GREEN}Now compiling and installing Newlib. This may take some time.${RESET}"
    CompBinutils > /dev/null 2>&1

    echo -e "\n${GREEN}Finishing compiling target libraries.${GREEN}"
    CompTLibs > /dev/null 2>&1
}

function main ()
{
    Prepare 
    Compile
    echo
    echo -e "\n${BLUE}🍎.mips64chain was successfully compiled and installed in your system. Enjoy!${RESET}"
    echo    "You may remove the build directory now. You don't need it anymore."
}

main
