# lsfg-vk
**Lossless Scaling** is a Windows-exclusive program featuring various algorithms for scaling and interpolating programs.

**lsfg-vk** is a Vulkan layer that hooks into Vulkan applications and generates additional frames using Lossless Scaling's frame generation algorithm.

>[!CAUTION]
> You are reading the README for the upcoming version 2.0 of lsfg-vk. For the stable version 1.x, [please read here](https://github.com/PancakeTAS/lsfg-vk/tree/ff1a0f72a7d6d08b84d58b7b4dc5f05c9f904f98)

## Installation
>[!TIP]
> If you are on a Steam Deck or similar handheld, consider using the [Decky plugin for lsfg-vk](https://github.com/xXJSONDeruloXx/decky-lsfg-vk). This is an easy way to install and configure lsfg-vk on the Steam Deck.
> Please keep in mind that it is not officially supported and support questions should be directed to the plugin's repository & discord.

1. Before proceeding, please make sure you have [Lossless Scaling](https://store.steampowered.com/app/993090/Lossless_Scaling/) downloaded on Steam.
2. Head to the [GitHub Releases](https://github.com/PancakeTAS/lsfg-vk/releases) and download the archive for your architecture:
  - `lsfg-vk-2.0.0-linux-x86_64.tar.xz`
  - `lsfg-vk-2.0.0-linux-aarch64.tar.xz`
3. Open a terminal in the folder where you downloaded the file and run the following:
```bash
tar -xvf lsfg-vk-2.0.0-linux-<arch>.tar.xz -C ~/.local
```
This will extract lsfg-vk to `~/.local`. Please **keep track of the files that were extracted**, in case you want to uninstall lsfg-vk later.

4. The graphical interface requires Qt6 and Qt6 Quick in order to run. If you do not have these installed, install the following packages:
```bash
sudo apt install qt6-qpa-plugins libqt6quick6 qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-window qml6-module-qtquick-dialogs qml6-module-qtqml-workerscript qml6-module-qtquick-templates qml6-module-qt-labs-folderlistmodel # On Debian/Ubuntu-based systems
sudo pacman -S qt6-declarative qt6-base # On Arch-based systems
sudo dnf install qt6-qtdeclarative qt6-qtbase # On Fedora
```

5. (Optional) If you wish to use lsfg-vk within Flatpak applications, see the [Flatpak Guide](docs/Flatpak-Guide.md).

## Usage
In order to start using lsfg-vk, you will need to configure it. This can either be done using the GUI application, or manually.

### Graphical Configuration
Start 'lsfg-vk Configuration Window' from your application launcher, or run `~/.local/bin/lsfg-vk-ui` in a terminal:
- On the left side, you will see a list of profiles. Each profile has its own settings.
- All properties in the "Global Settings" section apply to all profiles.
  - Should Lossless Scaling be installed in a non-standard location, you can specify the path here.
- Select a profile and configure the "Profile Settings" section to your liking.
  - When editing the "Active In" list, you can add a game using its executable name (e.g. `Game.exe`, `mpv`).
- Please see the [documentation](docs/Configuration.md) for detailed information on each setting.
- Once you are done configuring, simply starting a game that matches one of the profiles will automatically apply the settings.

### Manual Configuration
The default configuration is located in `~/.config/lsfg-vk/conf.toml`. It will be created automatically when any Vulkan application is started.
- In the `[global]` section, you can change where Lossless Scaling is installed, as well as other global settings.
- Each profile is defined in its own `[[profile]]` section.
- The `active_in` array/string defines which applications the profile is active in. You can add applications using their executable name (e.g. `Game.exe`, `mpv`).
- Please see the [documentation](docs/Configuration.md) for detailed information on each setting.
- Once you are done configuring, simply starting a game that matches one of the profiles will automatically apply the settings.

You can validate the configuration using `lsfg-vk-cli`:
```bash
~/.local/bin/lsfg-vk-cli validate
```


Comandi Utili: 

```bash
cd ~/lsfg-vk-aarch64

cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DLSFGVK_BUILD_UI=OFF -DLSFGVK_BUILD_CLI=ON -DLSFGVK_PORTABLE_ABI=ON -DLSFGVK_STATIC_LIBSTDCXX=ON

cmake --build build -j$(nproc)
sudo cmake --install build
sudo ldconfig

# Portable build helper (for custom runtimes like GameNative/Winlator)
./tools/build-portable.sh

# Docker portable pipeline (recommended for reproducible ABI baseline)
./tools/build-portable-docker.sh

# Windows PowerShell wrapper
./tools/build-portable-docker.ps1

# Runtime-specific release packages (recommended)
./tools/build-glibc.sh
./tools/build-bionic.sh

# Build both variants in sequence
./tools/build-all-runtime-variants.sh
```

### Runtime compatibility (glibc vs bionic)

`lsfg-vk-layer` is a native Linux shared library. In practice, glibc and bionic require separate builds.

- Use `build-glibc.sh` for GLIBC containers/runtimes.
- Use `build-bionic.sh` for Bionic (Android libc) containers/runtimes.
- Publish both release assets and select by runtime variant at deployment time.

Suggested asset names:
- `lsfg-vk-2.0.0-dev24-linux-aarch64-glibc.tar.xz`
- `lsfg-vk-2.0.0-dev24-linux-aarch64-bionic.tar.xz`

If the ABI check prints symbols such as `GLIBC_2.38`, `__isoc23_strtoul` or very new `GLIBCXX_3.4.xx`,
you need to build in an older toolchain/runtime baseline (for example Ubuntu 22.04) to maximize compatibility.

The runtime-variant pipelines write outputs to `dist/`:
- `dist/lsfg-vk-2.0.0-dev24-linux-aarch64-glibc/`
- `dist/lsfg-vk-2.0.0-dev24-linux-aarch64-glibc.tar.xz`
- `dist/abi-check-lsfg-vk-2.0.0-dev24-linux-aarch64-glibc.txt`
- `dist/lsfg-vk-2.0.0-dev24-linux-aarch64-bionic/`
- `dist/lsfg-vk-2.0.0-dev24-linux-aarch64-bionic.tar.xz`
- `dist/abi-check-lsfg-vk-2.0.0-dev24-linux-aarch64-bionic.txt`

If needed, change package names via:
```bash
LSFGVK_PACKAGE_NAME=lsfg-vk-2.0.0-dev25-linux-aarch64-glibc ./tools/build-glibc.sh
LSFGVK_PACKAGE_NAME=lsfg-vk-2.0.0-dev25-linux-aarch64-bionic ./tools/build-bionic.sh
```

PowerShell equivalent (glibc pipeline):
```powershell
./tools/build-portable-docker.ps1 -PackageName lsfg-vk-2.0.0-dev25-linux-aarch64-glibc
```

### Benchmarking Mode
You can run a frame generation benchmark using `lsfg-vk-cli`:
```bash
~/.local/bin/lsfg-vk-cli benchmark
```

By default, the benchmark will run for 10 seconds. Add `-h` to see all available benchmarking options.

## Support and Troubleshooting
If you encounter any issues or have questions regarding lsfg-vk, read through the [Troubleshooting](docs/Troubleshooting.md) documentation page or join the [Discord server](https://discord.gg/losslessscaling) for assistance.
