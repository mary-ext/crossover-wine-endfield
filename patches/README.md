# patches/

Applied to CrossOver's Wine 11.0 source by `scripts/build-modules.sh apply`, in this order: `stage2-dwproton/em-backports/*` → `stage2-dwproton/misc/*` → `stage1-macos/0000` → `stage1-macos/0001`.

## `stage2-dwproton/`

The Endfield-relevant subset of dw-proton commit `b816be489`, from [dawn-winery/dwproton-mirror](https://github.com/dawn-winery/dwproton-mirror). Refresh with `scripts/fetch-dwproton-patches.sh`.

- `em-backports/0001–0017`: `ntoskrnl.exe` functions ACE's driver calls (`KeAcquireGuardedMutex`, `PsGetProcessImageFileName`, `MmGetPhysicalMemoryRanges`, …).
- `misc/0009`, `misc/0010`: `GetProcAddress` spoof of `KiUserApcDispatcher` / `KiUserCallbackDispatcher`, limited to `Endfield.exe` / `EM-Win64-Shipping.exe`.
- `misc/0011`: `NtDelayExecution` relative waits via QueryPerformanceCounter.
- `misc/0008`: wintrust bypass for `winex11.drv` / `winewayland.drv`. It does nothing on macOS but applies cleanly.

## `stage1-macos/`

- `0001-macos-rosetta-signal-fixes-nop-and-privinstr.patch`, in `dlls/ntdll/unix/signal_x86_64.c`:
  - Skips `0F 1F` multi-byte NOPs that Rosetta 2 reports as illegal instructions (the game's protector uses them heavily).
  - Delivers `EXCEPTION_PRIV_INSTRUCTION` for privileged instructions such as `mov reg, cr3`, which Rosetta reports as invalid opcodes.
- `0000-build-fix-win32u-vulkan-soname-fallback.patch`: lets the minimal build without Vulkan compile.

## License

These are modifications to [Wine](https://www.winehq.org/) and are therefore **LGPL-2.1-or-later**; the repository's MIT license does not apply here. `stage2-dwproton/*` retain their upstream authorship (Etaash Mathamsetty, Ziia Shi / mkrsym1, NelloKudo and other dw-proton contributors).
