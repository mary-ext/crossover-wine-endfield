# patches/

Applied to CrossOver's Wine 11.0 source by `scripts/build-wine.sh apply`, in this order: `stage2-dwproton/em-backports/*` → `stage2-dwproton/misc/*` → `stage1-macos/*`.

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
- `0003-ntdll-don-t-close-the-msync-alert-index-on-thread-exit.patch`, in `dlls/ntdll/unix/thread.c`:
  - Skips closing `alert_fd` on thread exit under MSync: it holds a shared-memory index owned by the server. Closing it can close another thread's wineserver pipe and cause Unity's "SuspendThread loop failed" error.

## `moltenvk/`

Applied by `scripts/build-moltenvk.sh` to MoltenVK v1.4.2 and its pinned SPIRV-Cross revision (`spirv-cross/*`). Builds an x86_64 `libMoltenVK.dylib` into `build/moltenvk-out`.

- `spirv-cross/0001-msl-fence-device-scope-control-barriers.patch`: adds device-scope atomic fences around control barriers (MSL 3.2+). `threadgroup_barrier` alone leaves cross-threadgroup reads stale on Apple GPUs. Fixes the stuck work-queue shader in Snowy Forest.
- `0001-reject-pipeline-caches-without-the-barrier-fix.patch`: sets bit 31 of the Metal-features word in `pipelineCacheUUID` to reject cached MSL without the fences.

## License

[Wine](https://www.winehq.org/) patches are licensed LGPL-2.1-or-later; `moltenvk/` patches, Apache-2.0 like MoltenVK and SPIRV-Cross. `stage2-dwproton/*` retain upstream authorship (Etaash Mathamsetty, Ziia Shi / mkrsym1, NelloKudo and other dw-proton contributors).
