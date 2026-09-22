# crossover-wine-endfield

Patched Wine modules and MoltenVK for running Arknights: Endfield in CrossOver on Apple Silicon.

Forked from [stoicswe/Endfield_FineWine](https://github.com/stoicswe/Endfield_FineWine).

## Install prebuilt modules

```bash
./scripts/install-release.sh
```

Downloads the latest [release](https://github.com/mary-ext/crossover-wine-endfield/releases), verifies its checksum and creates `/Applications/CrossOver_Endfield_Patch.app`, preserving the original app. Set `TAG=<tag>` to select a release.

## Build from source

Requires Xcode and Homebrew. If `xcode-select` points at the Command Line Tools, set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

```bash
./scripts/build-wine.sh       # Wine modules -> build/wine-out
./scripts/build-moltenvk.sh   # libMoltenVK.dylib -> build/moltenvk-out
./scripts/package.sh         # both builds -> dist/
./scripts/apply-modules.sh   # install into a copy of CrossOver
```

The builds can run independently. To run a single step:

- `./scripts/build-wine.sh <step>`: `deps`, `fetch`, `apply`, `configure`, `build`.
  - `deps` installs bison, mingw-w64 and pkgconf.
- `./scripts/build-moltenvk.sh <step>`: `fetch`, `apply`, `deps`, `build`.

`CX_VER` selects the CrossOver source version (default `26.3.0`). `MVK_TAG` selects the MoltenVK release (default `v1.4.2`, the patch target).

## After installing

- If macOS blocks the first launch, open **System Settings → Privacy & Security → Open Anyway**.
- Enable **MSync** in the bottle's advanced settings.
- To update D3DMetal from Apple's [Game Porting Toolkit](https://developer.apple.com/games/game-porting-toolkit/), pass its disk image to `install-release.sh` or `apply-modules.sh`:

  ```bash
  GPTK=~/Downloads/Evaluation_environment_for_Windows_games_4.0_beta_2.dmg ./scripts/install-release.sh
  ```

## Patches

See [patches/README.md](patches/README.md).

## License

- `scripts/` and this README: [MIT](LICENSE).
- Wine patches (`patches/wine/`) and the built Wine modules: LGPL-2.1-or-later, Wine's license.
  - The dwproton patches retain upstream authorship; upstream provides no separate patch license.
- MoltenVK patches (`patches/moltenvk/`) and the built library: Apache-2.0, MoltenVK's license.

Not affiliated with CodeWeavers, Gryphline/Hypergryph, Tencent, or Apple. Running the game in an unsupported configuration may violate its terms of service.
