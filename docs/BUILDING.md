# Building and releasing

## Local Windows builds

Requirements:
- A supported Windows build machine with PowerShell 5.1+ (PowerShell 7 preferred),
  Git and `tar.exe`.
- Visual Studio C++ tools and Windows SDK: VS16-compatible **v142** for PHP
  8.2/8.3; VS17 **v143** for PHP 8.4/8.5. The PHP build helper detects the requested
  toolset and attempts to install missing components. Provision tools in advance
  if your machine cannot perform unattended installations.
- Internet access to GitHub, PECL and PHP's Windows build downloads.
- A licensed **x64 Oracle Client 11.2** installation or full-client ZIP containing
  OCI development headers and `oci.lib`.

Build all eight configurations:

```powershell
.\Build-OCI8.ps1 -OracleZip 'D:\media\V20609-01.zip'
```

Or build one variant from an installed Oracle Home:

```powershell
.\Build-OCI8.ps1 `
  -OracleHome 'C:\oracle\product\11.2.0\client_1' `
  -PhpVersions 8.3 -ThreadSafety nts `
  -WorkDir C:\oci8-build
```

Output is `C:\oci8-build\dist\php<minor>-<ts|nts>-x64\`, containing the DLL
and `SHA256.txt`. Use a work directory without spaces.

## Build implementation

`Build-OCI8.ps1` stages `include\oci.h` and `lib\oci.lib`. ZIP mode searches
ordinary files, then Oracle Universal Installer component JARs. If the media
cannot provide a usable SDK, install its development components and use
`-OracleHome` instead.

The script downloads OCI8 **3.4.1** and invokes the PHP team's
[BuildPhpExtension](https://github.com/php/php-windows-builder) module with
`--with-oci8-11g=<SDK>,shared`. The helper selects the PHP-series compiler ABI.
Its default OCI8 detection targets `oci8_19`; this script adapts that private
name detector **in the imported module's memory only** to target `oci8_11g`.
No installed module files or OCI8 source files are patched.

Build helper dependency autodetection and database-backed upstream tests are
disabled. Returned artifact ZIPs are extracted before collecting the named DLL.
The helper is downloaded directly from upstream commit
`68dc945d9509c41b72332c74c8b99731bb75bc25`, avoiding a PowerShell Gallery dependency.
`-SkipModuleInstall` instead uses an already installed module; review its version
and compatibility yourself. Review the adapter when changing the pinned revision.
PHP development packs and other downloads still resolve at run time, so identical
source does not promise bit-for-bit reproducibility.

## GitHub Actions

`.github/workflows/build.yml` uses `windows-2022` for eight independent jobs:
PHP 8.2/8.3/8.4/8.5 × TS/NTS, all x64. Package names distinguish VS16 and VS17.
Existing v142 components can be used alongside VS2022; missing-component setup
may add time. More matrix jobs increase total runner work; elapsed time depends
on setup, concurrency and runner queues.

- Pushes to `main` and manual dispatches build downloadable artifacts.
- Version-tag pushes also run the release job after every build succeeds.
- Successful build artifacts retain DLL/checksum files for 14 days.
- Failure diagnostics include build logs only, never Oracle media or SDK files.
- Public pull requests do not run secret-bearing jobs.

### Maintainer-only Oracle input

CI downloads `V20609-01.zip` from the private `weeix/oracle-client-assets`
repository, release `oracle-11.2.0.1-x64`. It validates this SHA256 before use:

```text
60063c214cf277a316cf20360f3de4c7830da7aa0ca02bc11386efaa344383f3
```

Configure **`ORACLE_ASSETS_TOKEN`** in the build repository's Actions secrets.
Use a fine-grained PAT restricted to **only the assets repository**, repository
**Contents: Read-only**, with an expiry. The token is provided as `GH_TOKEN` only
to the download step, not to compilation or release publication. The ordinary
build-repository `GITHUB_TOKEN` cannot read another private repository.

Forks do not inherit this access. Build locally with your own licensed SDK or
configure your own private-media source; never make proprietary media public
just to make a fork's workflow run. Public release downloads need no media token.

## Publishing a release

Push a new semantic version tag after reviewing and testing the source:

```bash
git tag -a v1.0.1 -m "OCI8 11g Windows builds v1.0.1"
git push origin v1.0.1
```

`Publish-Release.ps1` requires all eight named artifacts. It verifies their
allowlisted contents, DLL checksums and x64 PE architecture. Each release ZIP
contains only the DLL, its checksum, the upstream license and notices. A separate
`SHA256SUMS.txt` covers all ZIP files.

The release job has `contents: write`; build jobs have read-only repository
permissions. It creates a draft, uploads the verified files, then publishes.
An upload failure leaves a draft. Existing releases are not silently overwritten.
Do not grant the private Oracle media token to the release job.

## Validation scope

Successful CI establishes compilation and packaging, not production suitability.
Run `Test-OCI8.ps1` with a matching PHP/Oracle runtime, then perform application
and database tests described in [UPGRADE.md](UPGRADE.md). PHP2Shell fixes belong
to PHP itself; see [SECURITY.md](../SECURITY.md).
