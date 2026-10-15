# Patch reference

## `wine/`

Applied to CrossOver's Wine 11.0 source, in the following order:

1. `wine/upstream/*`.
2. `wine/dwproton/*`.
3. `wine/macos/*`.

### upstream Wine backports (`wine/upstream/`)

- `0001`–`0036`: `ntoskrnl.exe` functions ACE's drivers call, including guarded mutexes, bug check callback stubs, `PsGetProcessSessionId`, `PsGetProcessImageFileName`, `SeLocateProcessImageName`, `PsReferencePrimaryToken` and `MmGetPhysicalMemoryRanges`.
  - `0002`, `0024`: server support for directory and token kernel objects.
  - `0006`: driver security cookie update after relocation.
- `0037`–`0042`: MDL mapping and locking (`MmMapLockedPagesSpecifyCache`, `MmProbeAndLockPages`, `MmBuildMdlForNonPagedPool`); `dwproton/0007` needs the `MDL_PAGES_LOCKED` flag these set.
- `0043`: `PsGetContextThread`.

### dwproton patches (`wine/dwproton/`)

- `0001`, `0003`:
  - Returns an `int3` stub from `GetProcAddress` for `KiUserApcDispatcher` / `KiUserCallbackDispatcher` in `Endfield.exe` / `EM-Win64-Shipping.exe`, or any process with `PROTON_ENABLE_INT3_HACK=1`.
- `0002`:
  - Uses QueryPerformanceCounter for `NtDelayExecution` relative waits.
- `0004`:
  - Calls `DriverInit` with return-address bits 48–63 set to avoid an ACE-CORE bug check at entry.
- `0005`, `0006`:
  - Adds an `MmCopyMemory` stub; passes only the service name in `DriverExtension->ServiceKeyName`.
- `0007`, `0008`:
  - Defers unmapping section views while a locked MDL maps them; calls `PsGetContextThread` through a thunk.

The `_dw` `PsGetProcessExitStatus` stub (`d077b3f5c3`) is replaced by `macos/0005`; the csrss/lsass changes are adapted in `macos/0007`.

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
- `0005-ntoskrnl-implement-PsGetProcessExitStatus.patch`:
  - Implements `PsGetProcessExitStatus` to prevent the stub from aborting an ACE background thread.
  - Refreshes the cached status until exit; returns the cached value if querying fails.
- `0006-msync-query-time-only-for-relative-timeouts.patch`:
  - Reads the system clock only when converting a relative timeout to an absolute deadline.
  - Avoids an unused clock read for infinite waits and existing absolute deadlines; wait and wake behavior is unchanged.
- `0007-lsass-add-a-stub-started-by-wineboot.patch`:
  - Starts an `lsass.exe` stub with services so ACE-CORE can initialize. Source commits and adaptation details are in the patch header.

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
- `0003-compile-shader-libraries-outside-the-pipeline-cache-lock.patch`:
  - Converts SPIR-V and compiles `MTLLibrary` objects outside the pipeline cache lock. A per-module lock prevents duplicate compilation.
  - Compiles libraries from a loaded pipeline cache in parallel.
  - Protects specialization variants and error reporting against concurrent access.
- `0004-defer-cached-shader-libraries-and-replay-recorded-pipelines.patch`:
  - Compiles cached `MTLLibrary` objects on first use or in the background. Shares libraries with identical MSL and compile options.
  - Saves pipeline descriptors for background replay to warm Metal's shader cache. Verifies that each new recipe reconstructs the original descriptor; stores recipes after shader libraries so older readers ignore them.
  - `MVK_CONFIG_PIPELINE_CACHE_BACKGROUND_WORKERS` sets the worker count (default 4; 0 disables background work).
  - Retrieves and specializes Metal functions without the device-wide lock.
- `0005-make-vertex-positions-invariant.patch`:
  - Makes vertex and tessellation evaluation shader positions invariant so depth prepasses and subsequent EQUAL depth tests agree.
  - Fixes TAA smearing.
- `0006-reuse-resource-tracking-nodes.patch`:
  - Reuses resource-table nodes across Metal encoder passes within one command encoder, invalidating usage with a generation counter. Clears on generation wrap or when more than 4096 nodes are retained.
  - Uses a pointer-specific hash and power-of-two buckets to reduce lookup overhead. Metal resource-use calls remain unchanged.

## License

- Wine patches (`wine/`): LGPL-2.1-or-later, [Wine's](https://www.winehq.org/) license.
  - Imported patches retain author and source-commit metadata in their headers.
- MoltenVK patches (`moltenvk/`): Apache-2.0, like MoltenVK and SPIRV-Cross.
