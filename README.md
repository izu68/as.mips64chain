# 🍎.mips64chain

This script automatically sets up a GNU toolchain targeted towards mips64 systems in Apple Silicon Macs, specifically for N64 source compilation.

### Components and versions

- binutils 2.41
- GCC 13.2.0
- newlib 4.3(.0.20230120)
- GMP 6.3.0
- MPC 1.3.1
- MPFR 4.2.0

(These version numbers are hard-coded in the script, I'll change them whenever any significant updates are pushed to the toolchain by the GNU team, or you may change them yourself if you wanna use another version for other stuff.)

### Dependencies

- brew