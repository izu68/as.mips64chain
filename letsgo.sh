#!/bin/bash

######################################################
#                                                    #
#             Installation script for M64            #
#                       izu68                        #
#                                                    #
######################################################

# Variables
#variable1="value1"
#variable2="value2"

# Define ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
RESET='\033[0m'

function InstallToolchain ()
{
    
}

function main () 
{
    clear
    echo    ""
    echo -e "           Welcome to the ${RED}M64${RESET} installation script!"
    echo    "                                ~"
    echo -e "   This script will set up a mips64 toolchain based on"
    echo -e "   ${YELLOW}GCC 13.2${RESET}, recompile ${PURPLE}LibUltra${RESET} for use with this toolchain"
    echo -e "   and will copy all the original ${BLUE}UltraSDK${RESET} examples to the"
    echo -e "   install directory. All files will be available in ${GREEN}/opt/M64${RESET}"
    echo    ""

    while true; do
        read -p "                   Are you ready? [y / N] " answer
        case $answer in
            [Yy]* ) break;;
            * ) echo "" && echo -e "                           ${PURPLE}Bye-bye!${RESET}" && echo "" && exit 1;;
        esac
    done

    sudo mkdir /opt/M64
    sudo chown $(whoami) /opt/M64

    InstallToolchain
}

# Use variables
#echo "Variable 1: $variable1"
#echo "Variable 2: $variable2"

# Call a function
main

# Additional script logic goes here

# End of script
