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
  The patch makes both handlers return zeros, as Rosetta does. SHA-256 checks accept only the
  pinned build, including copies patched by earlier setup runs. CodeWeavers' FEX fork is not public.
- Patches FEX's overcommit fault handler (`OvercommitTracker::HandleAccessViolation`) to take
  its non-Wine path: commit up to 64 KiB at the faulting page instead of the whole reservation.
  Each emulated thread reserves a 272 MiB lookup cache, of which only the 16 MiB L1 is used
  with the default `DisableL2Cache`. The Wine path committed all of it on the first L1 touch.
  On macOS, reads of unwritten committed pages allocate physical memory. Apparent memory scans
  during gameplay pushed these caches past 30 GB across about 190 threads.
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

Memory use (`footprint`) and map-open frame times, measured at Dijiang Kernel Sector spawn
over 13 map opens per run:

| Build | After world load | After 7 opens | After 13 opens | Worst frame, map open (1st / later) |
| --- | ---: | ---: | ---: | ---: |
| Rosetta | 8.6 GB | 8.3 GB | | 262 / 58–71 ms |
| FEX, no memory patches | 26 GB | 47 GB | 54 GB | 183 / 92–108 ms |
| FEX, overcommit patch | 17 GB | 17 GB | 18 GB | 175 / 83–92 ms |
| FEX, overcommit patch + wine-preview `0012` | 14 GB | 14 GB | 14 GB | 175 / 83–96 ms |

With both memory patches, FEX reached 16 GB after a teleport to Wuling City (PAC, 102–103 FPS).
Mean FPS during spins at spawn stayed at 110–114 across all FEX builds.

## Known issues

- ACE-BASE runs a VMware backdoor probe (`IN EAX,DX` on port `0x5658`) during login, which
  faults ("Unhandled privileged instruction") under both FEX and Rosetta, terminating the driver
  host. Gameplay continues with the fault unhandled; emulating an empty port terminates the game
  at login. See [wine-preview `0011`](../../patches/README.md#wine-preview) for the dialog fix.
- FEX uses about 5 GB of dirty memory in top-down allocations (L1 lookup caches, JIT code and
  FEX's heap; individual contributions unmeasured), plus about 1 GB more game memory than Rosetta.
- Shader compilation can take several minutes on first launch.
