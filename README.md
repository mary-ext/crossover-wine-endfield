# crossover-wine-endfield

Patched Wine modules that let **Arknights: Endfield** run in CrossOver on Apple Silicon Macs.

This is CrossOver's own Wine source with the [dw-proton](https://dawn.wine/) anti-cheat patches and two small Rosetta 2 signal-handling fixes applied. Only three modules are rebuilt (`ntdll.so`, `kernel32.dll`, `ntoskrnl.exe`) and swapped into a copy of CrossOver; everything else is stock CrossOver.

Forked from [stoicswe/Endfield_FineWine](https://github.com/stoicswe/Endfield_FineWine).

## Requirements

- Apple Silicon Mac with Rosetta 2 (`softwareupdate --install-rosetta --agree-to-license`)
- A licensed **CrossOver 26.3** in `/Applications`. The modules must match the CrossOver version they were built from.
- Arknights: Endfield installed in a CrossOver bottle through the official launcher

## Install prebuilt modules

```bash
./scripts/install-release.sh
```

Downloads the latest release from [mary-ext/crossover-wine-endfield](https://github.com/mary-ext/crossover-wine-endfield/releases), verifies its checksum and creates `/Applications/CrossOver_Endfield_Patch.app`. Your original CrossOver is left untouched. Set `TAG=<tag>` to pick a specific release.

## Build the modules yourself

Needs the Xcode Command Line Tools and Homebrew.

```bash
./scripts/build-modules.sh    # installs bison, mingw-w64, pkgconf; builds in build/, packages into dist/
./scripts/apply-modules.sh    # creates the patched CrossOver copy from dist/endfield-wine-modules
```

The steps can also be run individually: `deps`, `fetch`, `apply`, `configure`, `build`, `package`. `CX_VER` selects the CrossOver source version (default `26.3.0`).

## After installing

- **First launch:** macOS blocks the copy because its signature was modified. Open **System Settings → Privacy & Security** and click **Open Anyway**.
- **Set the game's renderer to DirectX 11** in the launcher's graphics settings. Vulkan and DirectX 12 give a white screen. Game updates can reset this.
- **Optional:** to use a newer D3DMetal from Apple's [Game Porting Toolkit](https://developer.apple.com/games/game-porting-toolkit/) than the one bundled with CrossOver, pass the downloaded disk image to either install script:

  ```bash
  GPTK=~/Downloads/Evaluation_environment_for_Windows_games_4.0_beta_2.dmg ./scripts/install-release.sh
  ```

## CI and releases

[`.github/workflows/build.yml`](.github/workflows/build.yml) builds the modules on every push and pull request and uploads them as a workflow artifact. Pushing a `v*` tag also publishes a GitHub release with `endfield-wine-modules.tar.gz`, which `install-release.sh` downloads.

## Patches

See [patches/README.md](patches/README.md).

## License

- `scripts/` and this README: [MIT](LICENSE).
- `patches/` and the built modules: LGPL-2.1-or-later, Wine's license. The dw-proton patches keep their upstream authorship.
- This repository does not include CrossOver, Apple's GPTK, or the game.

Not affiliated with CodeWeavers, Gryphline/Hypergryph, Tencent, or Apple. Running the game in an unsupported configuration may violate its terms of service.
