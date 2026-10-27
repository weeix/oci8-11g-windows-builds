# OCI8 11g Windows builds

**Upgrade PHP without making Oracle Client 11.2 the blocker.**

Unofficial Windows x64 builds of **`php_oci8_11g.dll`**, compiled from PECL OCI8
3.4.1 for PHP **8.2, 8.3, 8.4 and 8.5**, in both **TS** and **NTS** variants.
Intended for administrators who must retain a licensed Oracle Client 11.2 while
moving applications to a patched PHP runtime.

> **The extension is not a PHP2Shell patch.** To address CVE-2026-109618 and
> CVE-2026-109619, upgrade PHP itself. Replacing only this DLL does not fix those
> vulnerabilities. Read the [security guidance](SECURITY.md) before deploying.

## Download

**[Download the latest release](https://github.com/weeix/oci8-11g-windows-builds/releases/latest)**

Choose the ZIP matching your PHP minor version, thread-safety mode and toolchain:

| PHP branch | Thread safety | Package toolchain | Architecture |
| --- | --- | --- | --- |
| 8.2 | TS or NTS | `vs16` / MSVC v142 | x64 |
| 8.3 | TS or NTS | `vs16` / MSVC v142 | x64 |
| 8.4 | TS or NTS | `vs17` / MSVC v143 | x64 |
| 8.5 | TS or NTS | `vs17` / MSVC v143 | x64 |

Example: `php_oci8_11g-php8.3-nts-vs16-x64.zip` is for PHP 8.3 NTS x64,
not PHP 8.4, TS, or a 32-bit installation.

Each ZIP contains:
- `php_oci8_11g.dll`
- `SHA256.txt` — DLL checksum
- `OCI8-LICENSE.txt` and `NOTICE.txt`

`SHA256SUMS.txt` on the release page checksums the ZIP files. Oracle installers,
SDK files, import libraries, runtime DLLs, PHP itself and VC++ redistributables
are **not included**.

## Install and validate

Follow the **[PHP upgrade and installation guide](docs/UPGRADE.md)** for runtime
selection, checksums, configuration, service restarts, loading tests and a staged
application/database validation checklist.

Quick isolated load test with your matching PHP runtime and Oracle Client:

```powershell
.\Test-OCI8.ps1 `
  -PhpExe 'C:\php\php.exe' `
  -Dll 'C:\downloads\oci8\php_oci8_11g.dll' `
  -OracleBin 'C:\oracle\product\11.2.0\client_1\BIN'
```

A successful CLI load does not prove the web server uses the same PHP binary,
configuration, environment or Oracle Home. Check the real serving process too.

## Scope and limitations

- Windows x64 only; no Linux or x86 binaries.
- Built against Oracle Client **11.2.0.1 x64** development files. Other client
  patch levels, server versions and application combinations require your tests.
- CI verifies compilation, x64 PE architecture and checksums for all eight
  variants. Runtime loading and real database connections are **not certified**.
- Retaining an obsolete client is a compatibility constraint, not a security
  recommendation. This project does not patch or support Oracle Client 11.2.
- Upgrading PHP may also require application, framework and other extension
  changes. No compatibility with an unsupported Windows release is promised.
- These are unofficial builds, not endorsed by the PHP Group or Oracle.

## Build from source

See **[Building and releasing](docs/BUILDING.md)** for local builds, toolchain
selection, private SDK access and the tag-triggered release workflow. Downloading
public releases does not require access to the private build-media repository.

## License and notices

The OCI8 binaries are covered by the [PHP License 3.01](licenses/OCI8-LICENSE.txt).
Keep the license and [acknowledgment](NOTICE.txt) with redistributed binaries.
Oracle Client must be obtained and licensed separately.
