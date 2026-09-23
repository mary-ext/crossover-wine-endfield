# crossover-wine-endfield

Patched Wine modules and MoltenVK for running Arknights: Endfield in CrossOver on Apple Silicon.

Forked from [stoicswe/Endfield_FineWine](https://github.com/stoicswe/Endfield_FineWine).

## Install prebuilt modules

```bash
./scripts/install-release.sh
```

Downloads the latest [release](https://github.com/mary-ext/crossover-wine-endfield/releases), verifies its checksum and creates `/Applications/CrossOver_Endfield_Patch.app`, preserving the original app.

## Build from source

Requires Xcode and Homebrew. If `xcode-select` points at the Command Line Tools, set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

```bash
./scripts/build-wine.sh       # Wine modules -> build/wine-out
./scripts/build-moltenvk.sh   # libMoltenVK.dylib -> build/moltenvk-out
./scripts/package.sh          # both builds -> dist/
./scripts/apply-modules.sh    # install into a copy of CrossOver
```

Pass a step name to run only that step:

- `./scripts/build-wine.sh <step>`: `deps`, `fetch`, `apply`, `configure`, `build`
  - `deps` installs bison, mingw-w64 and pkgconf.
  - `CX_VER=<version>`: selects the CrossOver source version.
- `./scripts/build-moltenvk.sh <step>`: `fetch`, `apply`, `deps`, `build`
  - `MVK_TAG=<tag>`: selects the MoltenVK release.

## After installing

- If macOS blocks the first launch, open **System Settings → Privacy & Security → Open Anyway**.
- Enable MSync in the bottle's advanced settings.
- Disable MoltenVK's synchronous queue submits

  Add this under `[EnvironmentVariables]` in `~/Library/Application Support/CrossOver/Bottles/<bottle>/cxbottle.conf`

  ```ini
  "MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS" = "0"
  ```

## Patches

See the [patch reference](patches/README.md) for application order, individual fixes and upstream sources.

## License

- `scripts/` and this README: [MIT](LICENSE).
- Wine patches (`patches/wine/`) and the built Wine modules: LGPL-2.1-or-later, Wine's license.
  - The dwproton patches retain upstream authorship; upstream provides no separate patch license.
- MoltenVK patches (`patches/moltenvk/`) and the built library: Apache-2.0, MoltenVK's license.

## Disclaimer

Not affiliated with CodeWeavers, Gryphline/Hypergryph, Tencent, or Apple. Running the game in an unsupported configuration may violate its terms of service.
