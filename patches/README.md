# patches/

Applied to CrossOver's Wine 11.0 source by `scripts/build-modules.sh apply`, in this order: `stage2-dwproton/em-backports/*` → `stage2-dwproton/misc/*` → `stage1-macos/*`.

## `stage2-dwproton/`

Endfield patches from dw-proton commit `b816be489` in [dawn-winery/dwproton-mirror](https://github.com/dawn-winery/dwproton-mirror). Fetch with `scripts/fetch-dwproton-patches.sh`; set `DWPROTON_SHA` to use another commit.

- `em-backports/0001–0017`: `ntoskrnl.exe` functions ACE's driver calls (`KeAcquireGuardedMutex`, `PsGetProcessImageFileName`, `MmGetPhysicalMemoryRanges`, …).
- `misc/0009`, `misc/0010`: `GetProcAddress` spoof of `KiUserApcDispatcher` / `KiUserCallbackDispatcher`, limited to `Endfield.exe` / `EM-Win64-Shipping.exe`.
- `misc/0011`: `NtDelayExecution` relative waits via QueryPerformanceCounter.
- `misc/0008`: wintrust bypass for `winex11.drv` / `winewayland.drv`; unused on macOS.

## `stage1-macos/`

- `0001-macos-rosetta-signal-fixes-nop-and-privinstr.patch`, in `dlls/ntdll/unix/signal_x86_64.c`:
  - Skips `0F 1F` multi-byte NOPs in the game's protector that Rosetta 2 reports as illegal instructions.
  - Delivers `EXCEPTION_PRIV_INSTRUCTION` for privileged instructions such as `mov reg, cr3`, which Rosetta reports as invalid opcodes.
- `0000-build-fix-win32u-vulkan-soname-fallback.patch`: defines `SONAME_LIBVULKAN` for builds without Vulkan.
- `0002-ntdll-bound-select-timeouts-in-NtDelayExecution.patch`, after `misc/0011`, in `dlls/ntdll/unix/sync.c`:
  - Caps `select()` waits at one day to avoid busy-looping on Darwin's `EINVAL` for timeouts over 10^8 seconds.
  - Waits indefinitely if a relative deadline would overflow, including for `INT64_MIN` timeouts.
- `0003-DEBUG-ntdll-log-thread-suspend-and-lifecycle-events.patch` (diagnostics branch only), in `dlls/ntdll/unix/thread.c`:
  - Diagnoses Unity's intermittent "Fatal error in GC: SuspendThread loop failed" during world loading.
  - Logs thread creation, exit, abort, cross-thread termination, and suspend/resume/context failures. Includes target details for the first three suspend failures.
  - Logs to `~/Library/Logs/Endfield-gcdiag/gcdiag-<time>-<pid>.log` for the executable named by `WINE_GCDIAG_IMAGE` (default `Endfield.exe`).

## License

[Wine](https://www.winehq.org/) patches are licensed LGPL-2.1-or-later. `stage2-dwproton/*` retain upstream authorship (Etaash Mathamsetty, Ziia Shi / mkrsym1, NelloKudo and other dw-proton contributors).
