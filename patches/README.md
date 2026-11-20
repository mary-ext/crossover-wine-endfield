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

### additional macOS patches (`wine/macos/`)

- `0000-build-fix-win32u-vulkan-soname-fallback.patch`:
  - Defines `SONAME_LIBVULKAN` for builds without Vulkan.
- `0001-macos-rosetta-signal-fixes-nop-and-privinstr.patch`:
  - Skips `0F 1F` multi-byte NOPs in the game's protector that Rosetta 2 reports as illegal instructions.
    - Lets the NOP fault when it has a LOCK prefix (hardware raises #UD there too), was read only partly, or exceeds 15 bytes.
    - Accepts `/1`–`/7` encodings as well as `/0`, since hardware executes them as NOPs.
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
  - Starts an `lsass.exe` stub with services so ACE-CORE can initialize.
- `0008-msync-fix-waitall-rollback.patch`:
  - Wakes sleepers after wait-all rollback and preserves prior mutex ownership and abandonment state.
- `0009-msync-don-t-spin-on-abandoned-mutexes-in-wait-all.patch`:
  - Prevents wait-all from spinning indefinitely on abandoned mutexes.
- `0010-msync-server-keep-one-waiter-node-per-thread.patch`:
  - Deduplicates waiter registrations to prevent unbounded wineserver memory growth.
  - Prints the pool-exhausted warning once.
- `0011-msync-server-unregister-object-0-when-object-1-is-signaled.patch`:
  - Fixes an off-by-one that left object 0 registered when object 1 was already signaled.
- `0012-ntdll-replace-stale-ntdll-symlink-in-winetemp-dir.patch`:
  - Refreshes the `winetemp/ntdll.so` symlink so CrossOver can launch after being moved or renamed.
- `0013-winemac-cache-the-window-under-the-cursor.patch`:
  - Caches the window under a stationary cursor for 50 ms to reduce WindowServer queries during mouse-look.
- `0014-winemac-skip-the-activation-display-resync-when-nothing-changed.patch`:
  - Skips the `DISPLAYS_CHANGED` event winemac sends on activation when the online displays, bounds and modes match the last activation resync. win32u answers that event by re-reading every display, mode, EDID and GPU and rewriting the display registry keys on the message thread, which hitches each switch back to a game.
  - Records the state only on activation: a process that doesn't own the desktop window ignores the other display events, so a change seen only through them still triggers a resync at the next activation.
- `0015-nsi-wait-for-cancelled-change-notifications.patch`:
  - Makes `NsiCancelChangeNotification` wait for the cancelled request to complete, as on Windows. Chromium (in the game process) frees the `OVERLAPPED` right after `CancelIPChangeNotify`, and the late status write corrupted whatever reused it.
  - From [upstream FineWine](https://github.com/stoicswe/Endfield_FineWine)'s `ARM/stage1-macos/0014`.

## `wine-preview/`

For CrossOver Preview 20261111's ARM64 Wine 11.21 (see [experiments/fex](../experiments/fex/README.md)).
`experiments/fex/build-wine.sh` applies these `wine/` patches first, then the series below:

- `dwproton/0001`, `0003`, `macos/0005`, `0006`, `0008`, `0009`, `0015`.
- Not applied:
  - `upstream/`: already in Wine 11.21.
  - `dwproton/0002`, `macos/0002`, `0003`: replaced by ports (`0010`, `0011` below).
  - `dwproton/0004`, `0008`: x86_64 only.
  - `dwproton/0005`–`0007`: would only reach the native ARM64 drivers; ACE-BASE runs on Preview's stock x86_64 ntoskrnl, which isn't rebuilt.
  - `macos/0001`: Rosetta only.
  - `macos/0004`, `0012`: don't apply; not ported yet.
  - `macos/0007`, `0010`, `0011`, `0013`, `0014`: change modules this build doesn't ship (lsass, wineboot, wineserver, winemac).

`setup.sh` also patches CodeWeavers' FEX build (`xtajit64.dll`, pinned by checksum):

- The CPUID hypervisor leaves `0x40000000` and `0x40000001` return zeros. `FEX_HIDEHYPERVISORBIT` only clears the hypervisor bit, and ACE exits with code 222 when it sees FEX's vendor leaf.
- `OvercommitTracker::HandleAccessViolation` takes its non-Wine path. Under Wine it commits the whole reservation around a faulting guard page, which is slow and wastes memory on macOS.

ACE driver support:

- `0001`: emulates native ARM64 driver reads of the shared-data page's kernel alias.
- `0002`: trims trailing NULs from registry value names passed by the ARM64 ACE drivers.
- `0003`: implements `IoGetBaseFileSystemDeviceObject`.
- `0004`: exports `PsGetProcessWow64Process` on ARM64.
- `0005`: adds a KMDF 1.15 `wdfldr.sys` binding for ARM64 ACE-CORE drivers. All 444 framework functions raise `STATUS_NOT_IMPLEMENTED`; none were called in the tested gameplay runs.
- `0006`: hosts x64 drivers in `winedevice-x64.exe` (`setup.sh` copies Preview's x86_64 `winedevice.exe`).
- `0007`: extends winedbg's crash-dialog exemption for `winedevice.exe` to `winedevice-x64.exe`, which otherwise shows a "Program Error" dialog when ACE-BASE faults.

Game and runtime fixes:

- `0008`: returns an x64 breakpoint page from the `dwproton/0001` dispatcher workaround on ARM64EC, where kernel32's own stub would run as ARM64 code.
- `0009`: hardens ARM64EC stack walks.
  - `RtlIsEcCode` returns false past the user address space instead of reading beyond the code map.
  - `RtlWalkFrameChain` stops at a frame without unwind data (as on x86_64), at a stack pointer that doesn't move up or leaves the thread's stack, and at a fault while unwinding.
  - IL2CPP backtraces through emulated frames otherwise followed stale stack words, and the fault's dispatch walked the same broken stack. The game hung or crashed ("invalid frame") while entering the world in about a quarter of launches.
- `0010`: `macos/0003` rebased; avoids closing the MSync alert index on thread exit.
- `0011`: `macos/0002` ported to Preview's `NtDelayExecution`; fixes a CPU spin on the game's `INT64_MIN` timeout.

macOS memory (16K host pages, emulator stacks above 4 GB):

- `0012`: commits only populated ARM64EC code-map pages, so memory scans don't fault in up to 4 GiB of zero pages. The full map stays readable for host code-range lookups.
- `0013`: uses `mincore()` to return zeros for untouched `NtAllocateVirtualMemory` pages in same-process `NtReadVirtualMemory`, so memory scans don't make them resident.
- `0014`: zeroes the 4K pages at the ends of a decommitted range that share a host page with committed memory. V8 decommits and recommits 4K pages constantly and crashed the launcher's renderer on the stale contents.
- `0015`: treats `KERN_INVALID_ADDRESS` as taken in free-area searches. arm64 macOS reserves everything below the program image, up to 4 GB, so searches above 4 GB failed at their first step once the startup reserve ran out, and threads (the game's `getaddrinfo()` thread) couldn't be created.
- `0016`: skips past host mappings with `mach_vm_region` instead of 64K probes. Every new thread's emulator stack search otherwise held `virtual_mutex` for seconds, stalling page faults on all threads (seconds-long frames at the title screen).

`0014`–`0016` are from upstream FineWine's `runtime/0016`, `0020` and `0031`.

Diagnostics:

- `0017`: traces IRPs (`+ntoskrnl`) and hard-error parameters (`warn+ntdll`).

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

- Wine patches (`wine/`, `wine-preview/`): LGPL-2.1-or-later, [Wine's](https://www.winehq.org/) license.
  - Imported patches retain author and source-commit metadata in their headers.
- MoltenVK patches (`moltenvk/`): Apache-2.0, like MoltenVK and SPIRV-Cross.
