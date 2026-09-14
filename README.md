# crossover-wine-endfield

Patched Wine modules for running Arknights: Endfield in CrossOver on Apple Silicon.

Builds `ntdll.so`, `kernel32.dll` and `ntoskrnl.exe` from CrossOver's Wine source with [dw-proton](https://dawn.wine/) anti-cheat patches and Rosetta 2 signal-handling fixes, then installs them into a copy of CrossOver.

Forked from [stoicswe/Endfield_FineWine](https://github.com/stoicswe/Endfield_FineWine).

## Install prebuilt modules

```bash
./scripts/install-release.sh
```

Downloads the latest [release](https://github.com/mary-ext/crossover-wine-endfield/releases), verifies its checksum and creates `/Applications/CrossOver_Endfield_Patch.app`, preserving the original app. Set `TAG=<tag>` to select a release.

## Build from source

Requires Xcode Command Line Tools and Homebrew.

```bash
./scripts/build-modules.sh    # installs bison, mingw-w64, pkgconf; builds in build/, packages into dist/
./scripts/apply-modules.sh    # creates the patched CrossOver copy from dist/endfield-wine-modules
```

Run a single step with `./scripts/build-modules.sh <step>`: `deps`, `fetch`, `apply`, `configure`, `build`, or `package`. Set `CX_VER` to select the CrossOver source version (default `26.3.0`).

## After installing

- If macOS blocks the first launch, open **System Settings → Privacy & Security → Open Anyway**.
- If DirectX 12 or Vulkan causes rendering issues, select **DirectX 11** in the game launcher's graphics settings. Game updates can reset this setting.
- To update D3DMetal from Apple's [Game Porting Toolkit](https://developer.apple.com/games/game-porting-toolkit/), pass its disk image to `install-release.sh` or `apply-modules.sh`:

  ```bash
  GPTK=~/Downloads/Evaluation_environment_for_Windows_games_4.0_beta_2.dmg ./scripts/install-release.sh
  ```

## CI and releases

[The build workflow](.github/workflows/build.yml) runs on relevant changes to `main` and pull requests, `v*` tags, or manual dispatch. It uploads the module archive and checksum as artifacts. Tags also publish these files as a GitHub release for `install-release.sh`.

## Patches

See [patches/README.md](patches/README.md).

## License

- `scripts/` and this README: [MIT](LICENSE).
- `patches/` and the built modules: LGPL-2.1-or-later, Wine's license. The dw-proton patches keep their upstream authorship.
- This repository does not include CrossOver, Apple's GPTK, or the game.

Not affiliated with CodeWeavers, Gryphline/Hypergryph, Tencent, or Apple. Running the game in an unsupported configuration may violate its terms of service.
