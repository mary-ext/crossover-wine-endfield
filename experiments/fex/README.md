# Endfield on the ARM64 CrossOver Preview (FEX)

Experimental port to CrossOver Preview **20260821**: ARM64 Wine 11.15 with CodeWeavers'
bundled FEX x86-64 translator (`xtajit64.dll`, FEX-2604-755-g80951b9). The app, bottle and
build outputs live in `build/fex/`.

## Requirements

- From CodeWeavers' preview program: `crossover-preview-arm64-20260821.zip` and
  `crossover-sources-20260821.tar.gz`. The sources are not on the public source mirror.
- Xcode (for MoltenVK), Homebrew. `build-wine.sh deps` installs autoconf and bison;
  `toolchain` downloads a pinned [llvm-mingw](https://github.com/mstorsjo/llvm-mingw) with ARM64EC support.
- An existing Endfield bottle to copy the game and profile from, or a fresh game installation.

## Build and set up

```sh
CX_PREVIEW_SRC=~/Downloads/crossover-sources-20260821.tar.gz experiments/fex/build-wine.sh
MVK_ARCH=arm64 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/build-moltenvk.sh
CX_PREVIEW_APP=~/Downloads/crossover-preview-arm64-20260821.zip \
FROM_BOTTLE="$HOME/Library/Application Support/CrossOver/Bottles/Endfield" \
  experiments/fex/setup.sh
```

`setup.sh` steps:

- `app`: extracts the preview as `build/fex/CrossOver FEX.app`.
- `bottle`: creates the ARM64 bottle `Endfield-FEX` (`WineArch=arm64`, `Preview=1`, MSync on).
  With `FROM_BOTTLE`, it clones the game, profile and registry settings. Quit the game and
  CrossOver first: exporting the registry briefly runs Wine in that bottle.
- `install`: installs the rebuilt modules and ARM64 MoltenVK, patches `xtajit64.dll` (below),
  and registers ACE-BASE. Originals are kept in `build/fex/stock/`.

On a fresh bottle, ACE is not installed yet. The first launch installs it and exits; run
`setup.sh install` again to register ACE-BASE, then launch.

## Run

```sh
experiments/fex/run.sh
```

For frame-time logs, prefix `MTL_HUD_ENABLED=1 MTL_HUD_LOG_ENABLED=1`. `FEX_WINEDEBUG` sets
Wine's debug channels (default `-all`). `WINEMSYNC`, `FEX_HIDEHYPERVISORBIT` and the MoltenVK
options live in the bottle's `cxbottle.conf`, which overrides the shell environment.

## What the port changes

Wine patch details and application order are in the
[patch reference](../../patches/README.md#wine-preview).

`setup.sh install` also:

- Patches FEX's `xtajit64.dll` to hide the hypervisor CPUID leaves. ACE terminates the game
  (exit status 222) when CPUID reports a hypervisor. `FEX_HIDEHYPERVISORBIT=1` clears leaf 1's
  bit, but leaves `0x40000000`/`0x40000001` still report `FEXIFEXIEMU` and FEX's version.
  The patch makes both handlers return zeros, as Rosetta does. SHA-256 checks restrict it to
  the expected stock or patched build. CodeWeavers' FEX fork is not public.
- Registers the game's x64 `ACE-BASE.sys`. The ARM64 ACE installer registers only native
  CORE drivers, but the x64 game also opens ACE-BASE (error `13-131078-288` if absent).

## Status (2026-10-03, M5 Pro, Very High, 2056×1329, 120 FPS cap)

Three launches reached signed-in gameplay with ACE running and no ACE warnings (up to 16 minutes,
teleports included), each exiting normally. Mean FPS over two slow 360° spins after warm-up:

| Spot | FEX, no MSync | FEX | Rosetta reference |
| --- | ---: | ---: | ---: |
| OMV Dijiang, Bridge | 56 | 105–111 | 105 (2026-09-28) |
| North Wuling, Celestial Column | | 97–98 | 100 (2026-09-24) |
| Wuling City, PAC | | 94 | 98 (2026-09-24) |

Without MSync, wineserver used 81% CPU on wait round trips. The Rosetta results use earlier
sessions and builds; these measurements don't establish a speedup.

## Known issues

- ACE-BASE faults on an `IN EAX,DX` at startup ("Unhandled privileged instruction"), and Wine
  shows a `winedevice-x64.exe` "Program Error" dialog. Dismiss it: the host and the driver stay
  loaded and play continues. Rosetta logs the same fault without a dialog; the difference is
  not yet understood.
- High memory use under FEX (50+ GB HUD App memory in gameplay).
- Shader compilation can take several minutes on first launch.
