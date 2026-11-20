# Endfield on the ARM64 CrossOver Preview (FEX)

Experimental ARM64 Wine and MoltenVK builds for running Arknights: Endfield with CrossOver Preview's FEX translator on Apple Silicon.

## Requirements

- CrossOver Preview `20261111`: `crossover-preview-arm64-20261111.zip` and `crossover-sources-20261111.tar.gz` from CodeWeavers' preview program. The scripts pin both checksums.
- Xcode and Homebrew. If `xcode-select` points at the Command Line Tools, set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- An existing Endfield bottle to copy, or a fresh game installation.

## Build from source

```bash
CX_PREVIEW_SRC=~/Downloads/crossover-sources-20261111.tar.gz experiments/fex/build-wine.sh
MVK_ARCH=arm64 scripts/build-moltenvk.sh
```

## Set up

Quit the game and CrossOver before copying an existing bottle:

```bash
CX_PREVIEW_APP=~/Downloads/crossover-preview-arm64-20261111.zip \
FROM_BOTTLE="$HOME/Library/Application Support/CrossOver/Bottles/Endfield" \
  experiments/fex/setup.sh
```

This creates `build/fex/CrossOver FEX.app` and a separate `Endfield-FEX` bottle, then installs the patched modules, ARM64 MoltenVK and the [`xtajit64.dll` patches](../../patches/README.md#wine-preview). The bottle sets:

- `WINEMSYNC=1` and `MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS=0`, as recommended for the main build.
- `FEX_HIDEHYPERVISORBIT=1`: ACE exits with code 222 when CPUID reports a hypervisor.
- `FEX_HOSTFEATURES=disableafp`: calls into Wine's native ARM64EC DLLs take about one-fifth the time by skipping two FPCR writes. Scalar SSE code is slower; gameplay FPS is unchanged, and map and menu hitches are 14–17% shorter.

Omit `FROM_BOTTLE` for a fresh bottle. After installing the game, the first launch installs ACE and exits. Run `experiments/fex/setup.sh install` again, then launch.

## Run

```bash
experiments/fex/run.sh
```

## Status and known issues

Tested with Preview 20261111 on an M5 Pro at Very High settings, 2056×1329 and a 120 FPS cap. ACE stayed quiet through teleports and hub menus, and 6 of 6 automated launches reached the world.

- Valley IV PAC holds 118 FPS and a warm map open takes about 400 ms, matching Preview 20260821. No same-sitting Rosetta comparison exists yet.
- Memory use is about 12.6 GB after a route through several regions. Rosetta uses about 8–9 GB at the measured spawn point.
- Shader compilation can take several minutes on first launch.

## Patches

See the [patch reference](../../patches/README.md#wine-preview) for application order and individual fixes.

## License and disclaimer

See the main README's [license](../../README.md#license) and [disclaimer](../../README.md#disclaimer).
