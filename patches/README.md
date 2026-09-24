# Patch reference

## `wine/`

Applied to CrossOver's Wine 11.0 source, in the following order:

1. `wine/dwproton/em-backports/*`.
2. `wine/dwproton/misc/*`.
3. `wine/macos/*`.

### dwproton patches (`wine/dwproton/`)

Taken from [`dawn-winery/dwproton-mirror#b816be489`](https://github.com/dawn-winery/dwproton-mirror/commit/b816be489049a10453b470c6a12dcf552ea41773)

- `em-backports/0001–0017`:
  - Implements `ntoskrnl.exe` functions ACE's driver calls, including `KeAcquireGuardedMutex`, `PsGetProcessImageFileName` and `MmGetPhysicalMemoryRanges`.
- `misc/0008`:
  - Bypasses wintrust for `winex11.drv` / `winewayland.drv`; unused on macOS.
- `misc/0009`, `misc/0010`:
  - Spoofs `GetProcAddress` for `KiUserApcDispatcher` / `KiUserCallbackDispatcher`, limited to `Endfield.exe` / `EM-Win64-Shipping.exe`.
- `misc/0011`:
  - Uses QueryPerformanceCounter for `NtDelayExecution` relative waits.

### additional macOS patches (`wine/macos/`)

- `0000-build-fix-win32u-vulkan-soname-fallback.patch`:
  - Defines `SONAME_LIBVULKAN` for builds without Vulkan.
- `0001-macos-rosetta-signal-fixes-nop-and-privinstr.patch`:
  - Skips `0F 1F` multi-byte NOPs in the game's protector that Rosetta 2 reports as illegal instructions.
  - Delivers `EXCEPTION_PRIV_INSTRUCTION` for privileged instructions such as `mov reg, cr3`, which Rosetta reports as invalid opcodes.
- `0002-ntdll-bound-select-timeouts-in-NtDelayExecution.patch`:
  - Caps `select()` waits at one day to avoid busy-looping on Darwin's `EINVAL` for timeouts over 10^8 seconds.
  - Waits indefinitely if a relative deadline would overflow, including for `INT64_MIN` timeouts.
- `0003-ntdll-don-t-close-the-msync-alert-index-on-thread-exit.patch`:
  - Skips closing `alert_fd` on thread exit under MSync: it holds a shared-memory index owned by the server.
  - Prevents closing another thread's wineserver pipe, which can cause Unity's "SuspendThread loop failed" error.
- `0004-msync-skip-wakes-without-sleepers-and-spin-before-sleeping.patch`:
  - Skips client wake syscalls for MSync objects with no registered sleepers.
  - Spins for 15 µs before sleeping on untimed object waits (`WINEMSYNC_SPIN_US` sets microseconds; `0` disables).

## MoltenVK

Applied to MoltenVK v1.4.2 and its pinned SPIRV-Cross submodule.

- `spirv-cross/0001-msl-fence-device-scope-control-barriers.patch`:
  - Adds device-scope atomic fences around control barriers (MSL 3.2+).
  - Fixes stale cross-threadgroup reads left by `threadgroup_barrier` alone on Apple GPUs, resolving the stuck work-queue shader in Snowy Forest.
- `0001-reject-pipeline-caches-without-the-barrier-fix.patch`:
  - Sets bit 31 of the Metal-features word in `pipelineCacheUUID` to reject cached MSL without the fences.
- `0002-use-metal-hazard-tracking-instead-of-barrier-fences.patch`:
  - Replaces per-stage `MTLFence`s with Metal's per-resource hazard tracking (`useResource`) so unrelated GPU passes can overlap.
  - Retains the residency set.

## License

- Wine patches (`wine/`): LGPL-2.1-or-later, [Wine's](https://www.winehq.org/) license.
  - dwproton patches (`wine/dwproton/`) retain upstream authorship: Etaash Mathamsetty, Ziia Shi / mkrsym1, NelloKudo and other dwproton contributors.
- MoltenVK patches (`moltenvk/`): Apache-2.0, like MoltenVK and SPIRV-Cross.
