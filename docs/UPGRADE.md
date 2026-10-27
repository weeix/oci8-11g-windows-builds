# PHP upgrade and OCI8 installation

This guide is for Windows administrators moving to patched PHP while retaining
Oracle Client 11.2. Start with [security guidance](../SECURITY.md): this DLL is a
compatibility component, not the PHP2Shell fix.

## 1. Inventory and prepare

1. Back up application files and configuration. Record the active PHP executable,
   patch version, architecture, TS/NTS mode, extensions, SAPI, loaded `php.ini`,
   Oracle Home and service-account environment.
2. Check application/framework support for the target PHP release and upgrade
   other extensions to matching builds. Use a separate staging installation.
3. Obtain a current patched PHP Windows x64 runtime from your trusted PHP vendor.
   The branch-specific PHP2Shell minimums are in [SECURITY.md](../SECURITY.md).
4. Retain your licensed x64 Oracle Client 11.2 runtime and its required dependency
   chain. This project does not install it or supply its DLLs.
5. Install the Visual C++ runtime required by your chosen PHP distribution.
   Do not fix runtime errors by copying random `VCRUNTIME140.dll` files into PHP.

Inspect the selected PHP runtime explicitly rather than relying on `PATH`:

```powershell
& 'C:\php\php.exe' -v
& 'C:\php\php.exe' --ini
& 'C:\php\php.exe' -i | Select-String 'Architecture|Thread Safety|PHP Extension Build'
```

Use the TS package if that runtime reports thread safety enabled; use NTS if it
reports disabled. Do not guess from the web server's name alone.

## 2. Download and verify

From [GitHub Releases](https://github.com/weeix/oci8-11g-windows-builds/releases/latest),
download the matching ZIP and `SHA256SUMS.txt`. Match **all** of PHP minor version,
TS/NTS, x64 and VS16/VS17. For example:

- PHP 8.2/8.3: `vs16` packages (v142).
- PHP 8.4/8.5: `vs17` packages (v143).

Compare the ZIP hash with its named entry in the release manifest:

```powershell
Get-FileHash '.\php_oci8_11g-php8.3-nts-vs16-x64.zip' -Algorithm SHA256
Get-Content '.\SHA256SUMS.txt'
```

After extraction, verify the DLL as well:

```powershell
Get-FileHash '.\php_oci8_11g.dll' -Algorithm SHA256
Get-Content '.\SHA256.txt'
```

Keep `OCI8-LICENSE.txt` and `NOTICE.txt` with the binary when redistributing it.

## 3. Test loading before changing the service

Clone/download this repository to obtain `Test-OCI8.ps1`, then run:

```powershell
.\Test-OCI8.ps1 `
  -PhpExe 'C:\php\php.exe' `
  -Dll 'C:\downloads\oci8\php_oci8_11g.dll' `
  -OracleBin 'C:\oracle\product\11.2.0\client_1\BIN'
```

This uses `php -n` to isolate the test from existing configuration and temporarily
prepends Oracle's `BIN` directory to the child process environment. It checks OCI8
module information, `extension_loaded('oci8')` and `function_exists('oci_connect')`.
It does **not** connect to a database or change the system/service environment.

## 4. Configure the target installation

Copy the matching `php_oci8_11g.dll` into the target PHP `ext` directory and enable
it in the `php.ini` actually used by that installation:

```ini
extension=php_oci8_11g.dll
```

Do not load another OCI8 DLL simultaneously. Configure the web/PHP service's
Oracle runtime search path to use the intended Oracle Home; the CLI test's PATH
change does not configure the service. Preserve required application-specific
Oracle settings, including TNS configuration where applicable.

Restart every PHP/web worker. Verify the web server or FastCGI handler points to
the new executable and configuration. If using a diagnostic web endpoint, restrict
it to administrators and remove it after validation; do not expose `phpinfo()`
publicly.

## 5. Validate the application

- Verify the patched PHP version, TS/NTS, configuration and OCI8 module in the
  real serving process. A different CLI PHP installation proves nothing about it.
- Review startup logs for extension loading failures, deprecations and errors.
- Test database connectivity, character encoding, reads, writes, transactions,
  rollback, LOBs and any persistent-connection behavior the application uses.
- Test request handling, background jobs and scheduled jobs that may use a
  separate PHP executable. Monitor errors and resource consumption after rollout.
- Use staging and a controlled cutover. If a test fails, do not leave an
  internet-facing service on a known-vulnerable PHP runtime as the long-term fix.

## Troubleshooting

**“The specified module could not be found” despite the DLL being present:**
check Oracle runtime dependencies and the service-account PATH, not just the
extension path. Check that the intended `OCI.dll` is x64 and from the intended
Oracle Home.

**“Not a valid Win32 application”:** check for x86/x64 mismatch or corrupt files.
Recheck checksums and all dependent DLL architectures.

**“Module compiled with module API … / PHP compiled with module API …”:** use a
package for the exact PHP minor branch and compatible build ABI.

**Entry point/runtime errors:** check TS versus NTS, VS16 versus VS17, PHP's
Visual C++ runtime requirements, Oracle patch level and conflicting Oracle Homes.
Do not rename a different OCI8 binary to make its filename appear compatible.

**CLI works, web fails:** check the service's executable, SAPI, `php.ini`,
`extension_dir`, account permissions and Oracle environment, then fully restart
workers. Do not assume your interactive environment is inherited by a service.
