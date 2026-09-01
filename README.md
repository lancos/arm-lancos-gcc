## Intro
Builds a bare-metal cross GNU toolchain for Linux targetting the ARM CortexM
microprocessor in EABI mode and using the newlib embedded C library.

## newlib-nano

The toolchain carries two variants of the C library inside the same multilib
tree: the default one and a size-optimized *nano* one (`libc_nano.a` & co.),
built from the same sources with `--enable-newlib-nano-malloc` and
`--enable-newlib-nano-formatted-io`. The GCC multilibs are not duplicated:
`libgcc` is shared between the two variants.

Select the nano variant at compile and link time with `--specs=nano.specs`:

    arm-lancos-eabi-gcc -mcpu=cortex-m0plus --specs=nano.specs --specs=nosys.specs main.c

Floating point support in `printf`/`scanf` is not linked in: add
`-u _printf_float` / `-u _scanf_float` when needed. Note that the nano
`printf`/`scanf` do not support `%ll`, `%z`, `%j`, `%t`, long double and
positional arguments.

Set `ENABLE_NANO=no` in `build-gcc-arm.sh` to skip the second newlib build, or
narrow `NANO_MULTILIBS` (default `all`) down to the multilib subdirectories you
actually need, as printed by `gcc -print-multi-lib` (e.g. `thumb/v6-m/nofp` for
CortexM0/M0+ only).
