# Endfield on the ARM64 CrossOver Preview (FEX)

Experimental ARM64 Wine and MoltenVK builds for running Arknights: Endfield with CrossOver Preview's FEX translator on Apple Silicon.

## Requirements

- CrossOver Preview `20260821`: `crossover-preview-arm64-20260821.zip` and `crossover-sources-20260821.tar.gz` from CodeWeavers' preview program.
- Xcode and Homebrew. If `xcode-select` points at the Command Line Tools, set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- An existing Endfield bottle to copy, or a fresh game installation.

## Build from source

```bash
CX_PREVIEW_SRC=~/Downloads/crossover-sources-20260821.tar.gz experiments/fex/build-wine.sh
MVK_ARCH=arm64 scripts/build-moltenvk.sh
```

## Set up

Quit the game and CrossOver before copying an existing bottle:

```bash
CX_PREVIEW_APP=~/Downloads/crossover-preview-arm64-20260821.zip \
FROM_BOTTLE="$HOME/Library/Application Support/CrossOver/Bottles/Endfield" \
  experiments/fex/setup.sh
```

Creates `build/fex/CrossOver FEX.app` and a separate `Endfield-FEX` bottle with MSync enabled, then installs the patched modules and ARM64 MoltenVK.

Omit `FROM_BOTTLE` for a fresh bottle. After installing the game, the first launch installs ACE and exits. Run `experiments/fex/setup.sh install` again, then launch.

## Run

```bash
experiments/fex/run.sh
```

## Status and known issues

Tested on an M5 Pro at Very High settings, 2056×1329 and a 120 FPS cap (2026-10-03). Gameplay reached roughly 96–118 FPS in tested areas, comparable to earlier Rosetta runs. Sessions up to 16 minutes included teleports and exited normally without ACE warnings.

- Setup sets `FEX_HOSTFEATURES=disableafp`. Calls into Wine's native ARM64EC DLLs take about one-fifth the time by avoiding two FPCR writes (~9 ns each). Scalar SSE code slows down; gameplay FPS is similar, but map and menu hitches are 14–17% shorter.
- Memory use after loading is about 10 GB, down from 16 GB before patch `0013`, and reaches 12 GB after touring four regions. Rosetta uses about 8–9 GB at the measured spawn point.
- Shader compilation can take several minutes on first launch.

## Patches

See the [patch reference](../../patches/README.md#wine-preview) for application order, individual fixes and upstream sources.

## License and disclaimer

See the main README's [license](../../README.md#license) and [disclaimer](../../README.md#disclaimer).
