# pkglet

`pkglet` (executed via the `pl` command) is a hybrid package manager designed for NULL GNU/Linux. It provides flexiblity for managing packages, supporting both binary and source-based installations.

## Features

*   **Hybrid Installation:** Install packages from pre-built binaries or compile them directly from source.
*   **Repository Management:** Easily update and add new package repositories. Uses Git.
*   **Dependency Resolution:** Automatically resolves and installs package dependencies.
*   **System Bootstrap:** A specialized bootstrap mode allows for installing packages to an arbitrary root directory, facilitating system setup in chroot environments or new partitions.
*   **Package Management:** List installed packages and upgrade them to their latest versions.

## Usage

The primary command-line interface for `pkglet` is `pl`.

```
Usage:
  pl <package>                Install package (binary)
  pl b/<package> [...]        Build package(s) from source
  pl u                        Update repositories
  pl uu                       Upgrade installed packages
  pl l                        List installed packages
  pl -b=<path> <packages...>  Bootstrap mode (install to specified directory)
  pl -bn=<path> <packages...> Bootstrap mode without filesystem initialization
  pl -v, --version            Show version
  pl -h, --help               Show this help
```

### Examples

*   **Install a binary package:**
    ```bash
    pl com.example.hello
    ```
*   **Build a package from source:**
    ```bash
    pl b/xyz.obsidianos.obsidianctl
    ```
*   **Install multiple packages, some from source:**
    ```bash
    pl b/com.example.pkg1 com.example.pkg2
    ```
*   **Bootstrap a new system to `/mnt` with base packages:**
    ```bash
    pl -b=/mnt com.example.base b/org.kernel.linux b/org.lua.lua net.busybox.busybox org.libc.musl
    ```

## Configuration

`pkglet` stores its configuration and data in the following locations:

*   **Repositories:** `~/.local/share/pkglet/repos`
*   **Cache:** `~/.cache/pkglet`
*   **Installed Database:** `~/.local/share/pkglet/installed.db`
*   **User Configuration:** `~/.config/pkglet/config.lua`

## License

This project is licensed under the [MIT License](LICENSE).
