#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^v[0-9]+\.[0-9]+\.[0-9]+$')][string] $Tag,
    [string] $InputDir = 'release-input',
    [string] $OutputDir = 'release-packages'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = 'weeix/oci8-11g-windows-builds'
if ($env:GITHUB_REPOSITORY -ne $repo) { throw 'Publishing is restricted to the upstream repository.' }
if (Test-Path -LiteralPath $OutputDir) { throw 'Output directory already exists; use a clean workspace.' }
New-Item -ItemType Directory -Path $OutputDir | Out-Null
$checksums = @()
$archives = @()
foreach ($php in @('8.2','8.3','8.4','8.5')) {
    $vs = if ($php -in @('8.2','8.3')) { 'vs16' } else { 'vs17' }
    foreach ($ts in @('ts','nts')) {
        $name = "php_oci8_11g-php$php-$ts-$vs-x64"
        $src = Join-Path $InputDir $name
        $dll = Join-Path $src 'php_oci8_11g.dll'
        $hashFile = Join-Path $src 'SHA256.txt'
        $expectedFiles = @('php_oci8_11g.dll','SHA256.txt')
        $files = @(Get-ChildItem -LiteralPath $src -File -Recurse)
        if ($files.Count -ne 2 -or @($files | Where-Object { $_.Name -notin $expectedFiles }).Count) {
            throw "Unexpected artifact contents: $name"
        }
        $record = (Get-Content -LiteralPath $hashFile -Raw).Trim()
        if ($record -notmatch '^SHA256 ([A-Fa-f0-9]{64})  php_oci8_11g\.dll$') { throw "Invalid checksum record: $name" }
        $expected = $Matches[1]
        if ((Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash -ne $expected) { throw "DLL checksum mismatch: $name" }
        $bytes = [IO.File]::ReadAllBytes($dll)
        $pe = [BitConverter]::ToInt32($bytes, 0x3c)
        if ([BitConverter]::ToUInt32($bytes, $pe) -ne 0x4550 -or [BitConverter]::ToUInt16($bytes, $pe + 4) -ne 0x8664) { throw "Not an x64 PE: $name" }
        $stage = Join-Path $OutputDir $name
        New-Item -ItemType Directory -Path $stage | Out-Null
        Copy-Item -LiteralPath $dll, $hashFile, "$PSScriptRoot/NOTICE.txt" -Destination $stage
        Copy-Item -LiteralPath "$PSScriptRoot/licenses/OCI8-LICENSE.txt" -Destination $stage
        $zip = Join-Path $OutputDir "$name.zip"
        Compress-Archive -Path "$stage/*" -DestinationPath $zip
        $archives += $zip
        $checksums += "$((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant())  $name.zip"
    }
}
$checksumFile = Join-Path $OutputDir 'SHA256SUMS.txt'
$checksums | Set-Content -LiteralPath $checksumFile -Encoding utf8NoBOM
$notesFile = Join-Path $OutputDir 'release-notes.md'
@"
Unofficial OCI8 3.4.1 extension builds for PHP 8.2-8.5, x64, TS and NTS, linked against Oracle Client 11.2.0.1. PHP 8.2/8.3 packages use VS16/v142; PHP 8.4/8.5 use VS17/v143.

For operators upgrading PHP while retaining Oracle Client 11.2. **This DLL is not a PHP2Shell patch:** upgrade the PHP runtime itself. PHP's advisories list 8.2.35, 8.3.36, 8.4.27 and 8.5.12 as the first patched versions for CVE-2026-109618 and CVE-2026-109619; use these or newer patched releases within the corresponding branch. See https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w and https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp .

Each ZIP contains php_oci8_11g.dll, its SHA256 checksum, the PHP License 3.01 and notices. SHA256SUMS.txt checksums the ZIP files.

**No Oracle Client components are included.** Install a licensed matching Oracle Client separately. Match the PHP minor version, TS/NTS, x64 architecture and Visual C++ runtime.

Compilation, PE architecture and checksums verified. Runtime loading and database connections are not yet tested. Oracle 11.2 is obsolete; no production security support is implied.

Source: $env:GITHUB_SHA
Build: https://github.com/$repo/actions/runs/$env:GITHUB_RUN_ID
"@ | Set-Content -LiteralPath $notesFile -Encoding utf8NoBOM
# Publish only after all eight packages have passed verification. Fail instead of
# silently replacing an existing release. The tag must already exist remotely.
gh release create $Tag --repo $repo --verify-tag --draft --title "OCI8 11g extension builds for PHP - $Tag" --notes-file $notesFile
if ($LASTEXITCODE -ne 0) { throw 'Release creation failed.' }
gh release upload $Tag @archives $checksumFile --repo $repo
if ($LASTEXITCODE -ne 0) { throw 'Release upload failed; release remains a draft.' }
gh release edit $Tag --repo $repo --draft=false --latest
if ($LASTEXITCODE -ne 0) { throw 'Release publication failed.' }
