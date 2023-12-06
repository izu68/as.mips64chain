# 🍎.mips64chain

This script automatically sets up a GNU toolchain targeted towards mips64 systems in Apple Sillicon Macs, specifically for N64 source compilation. This script is meant to be used with M64, but can be used elsewhere.

### Components and versions

- binutils 2.41
- GCC 13.2.0
- newlib 4.3(.0.20230120)
- GMP 6.3.0
- MPC 1.3.1
- MIFR 4.2.0

(These version numbers are hard-coded in the script, I'll change them whenever any significant updates are pushed to the toolchain by the GNU team, or you may change them yourself if you wanna use another version for other stuff.)

### Credit

This script is based on libdragon's toolchain installation script, a few changes have been made, like removing redundancy when checking for darwin since this script is intended to be ran on Macs.

Huge props to them for everything they're doing and big shoutouts to the N64brew community for their giant efforts 👏🏼
