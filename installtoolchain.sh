#! /bin/bash

######################################################
#                                                    #
#             MIPS64 toolchain installer             #
#     forked off libdragon's build-toolchain.sh      #
#                       izu68                        #
#                                                    #
######################################################

# Configure BASH strict mode
set -euo pipefail
IFS=$'\n\t'

export TMP_INS=/opt/M64/mips64chain

# Path where the toolchain will be built.
BUILD_PATH="${BUILD_PATH:-toolchain}"
# Defines the build system variables to allow cross compilation.
N64_BUILD=${MIPS64_BUILD:-""}
N64_HOST=${MIPS64_HOST:-""}
N64_TARGET=${MIPS64_TARGET:-mips64}
# Set N64_INST before calling the script to change the default installation directory path
INSTALL_PATH="${TMP_INS}"
# Set PATH for newlib to compile using GCC for MIPS N64 (pass 1)
export PATH="$PATH:$INSTALL_PATH/bin"

# Determine how many parallel Make jobs to run based on CPU count
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN)}"
JOBS="${JOBS:-1}" # If getconf returned nothing, default to 1

# GCC configure arguments to use system GMP/MPC/MFPF
GCC_CONFIGURE_ARGS=()

# Dependency source libs (Versions)
BINUTILS_V=2.41
GCC_V=13.2.0
NEWLIB_V=4.3.0.20230120
GMP_V=6.3.0 
MPC_V=1.3.1 
MPFR_V=4.2.0
MAKE_V=${MAKE_V:-""}

# Check command availability (0 = y, 1 = n)
function IsCommandAvail () 
{
    command -v "$1" >/dev/null 2>&1
    return $?
}

# Download necessary files
function Download ()
{
    if IsCommandAvail curl ; then 
        curl -LO "$1"
    else
        echo "curl isn't installed, it'll be installed now." >&2
        brew install -q curl
        prep "$1"
    fi
}

function LetsGo ()
{
    brew install -q gmp mpfr libmpc gsed

    # Configure dependent libs for GCC
    GCC_CONFIGURE_ARGS=
    (
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
}


LetsGo