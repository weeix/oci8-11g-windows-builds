#requires -Version 5.1
<##
Build php_oci8_11g.dll for PHP 8.2-8.5, both TS and NTS, x64.
Uses PECL OCI8 3.4.1 and the PHP team's BuildPhpExtension module.
Uses OCI headers / oci.lib from an Oracle full-client ZIP (or installed Oracle Home).
The builder selects VS16/v142 for PHP 8.2-8.3 and VS17/v143 for PHP 8.4-8.5.
##>
[CmdletBinding(DefaultParameterSetName='Zip')]
param(
    [Parameter(Mandatory=$true, ParameterSetName='Zip')]
    [string] $OracleZip,
    [Parameter(Mandatory=$true, ParameterSetName='Home')]
    [string] $OracleHome,
    [string] $WorkDir = 'C:\oci8-build',
    [ValidateSet('8.2','8.3','8.4','8.5')]
    [string[]] $PhpVersions = @('8.2','8.3','8.4','8.5'),
    [ValidateSet('ts','nts')]
    [string[]] $ThreadSafety = @('ts','nts'),
    [switch] $SkipModuleInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ociVersion = '3.4.1'

function Require-Path([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Path not found: $Path" }
    return (Resolve-Path -LiteralPath $Path).Path
}
function Prepare-Dir([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}
function Copy-HeaderTree([string] $HeaderPath, [string] $Destination) {
    # The parent of oci.h is expected to contain the companion Oracle SDK headers.
    $folder = Split-Path -Parent $HeaderPath
    $headers = @(Get-ChildItem -LiteralPath $folder -File -Recurse |
        Where-Object { $_.Extension -in @('.h','.hpp','.inl') })
    foreach ($file in $headers) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $Destination $file.Name) -Force
    }
    Write-Host "Copied $($headers.Count) SDK headers from $folder"
}
function Prepare-FromDirectory([string] $Directory, [string] $IncludeDir, [string] $LibDir) {
    $heads = @(Get-ChildItem -LiteralPath $Directory -Filter 'oci.h' -File -Recurse)
    $libs = @(Get-ChildItem -LiteralPath $Directory -Filter 'oci.lib' -File -Recurse)
    if ($heads.Count -eq 0 -or $libs.Count -eq 0) { return $false }

    $header = $heads | Sort-Object @{Expression={
        if ($_.FullName -match '(?i)[\\/]oci[\\/]include[\\/]oci\.h$') { 0 }
        elseif ($_.FullName -match '(?i)[\\/]include[\\/]oci\.h$') { 1 }
        else { 2 }
    }},FullName | Select-Object -First 1
    $lib = $libs | Sort-Object @{Expression={
        if ($_.FullName -match '(?i)[\\/]oci[\\/]lib[\\/]msvc[\\/]oci\.lib$') { 0 }
        elseif ($_.FullName -match '(?i)[\\/]lib[\\/]msvc[\\/]oci\.lib$') { 1 }
        else { 2 }
    }},FullName | Select-Object -First 1
    Copy-HeaderTree -HeaderPath $header.FullName -Destination $IncludeDir
    Copy-Item -LiteralPath $lib.FullName -Destination (Join-Path $LibDir 'oci.lib') -Force
    Write-Host "Using import library: $($lib.FullName)"
    return $true
}
function Prepare-FromOUIArchives([string] $MediaDir, [string] $IncludeDir, [string] $LibDir) {
    # OUI installation media commonly stores components in .jar ZIP-format archives.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archives = @(Get-ChildItem -LiteralPath $MediaDir -Recurse -File |
        Where-Object { $_.Extension -in @('.jar','.zip') })
    $headerCount = 0
    $libFound = $false
    foreach ($archivePath in $archives) {
        $zip = $null
        try {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath.FullName)
            $entries = @($zip.Entries)
            $hasOciH = @($entries | Where-Object { $_.Name -ieq 'oci.h' }).Count -gt 0
            $fromOciInclude = @($entries | Where-Object {
                $_.FullName -match '(?i)(^|/)oci/include/.+\.(h|hpp|inl)$'
            }).Count -gt 0
            foreach ($entry in $entries) {
                if ($entry.Name -ieq 'oci.lib' -and -not $libFound) {
                    $target = Join-Path $LibDir 'oci.lib'
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
                    $libFound = $true
                    Write-Host "Found oci.lib in archive: $($archivePath.Name)"
                }
                if ((($hasOciH -or $fromOciInclude) -and
                    $entry.Name -match '(?i)\.(h|hpp|inl)$') -and $entry.Length -gt 0) {
                    $target = Join-Path $IncludeDir $entry.Name
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
                    $headerCount++
                }
            }
        }
        catch {
            Write-Warning "Cannot inspect archive $($archivePath.FullName): $_"
        }
        finally { if ($null -ne $zip) { $zip.Dispose() } }
    }
    Write-Host "Extracted $headerCount headers from OUI component archives"
    return ($headerCount -gt 0 -and $libFound)
}

$WorkDir = [System.IO.Path]::GetFullPath($WorkDir)
# The PHP Windows configure tool handles spaces inconsistently in --with options.
if ($WorkDir -match '\s') { throw 'Please use a WorkDir without spaces, e.g. C:\oci8-build.' }
Prepare-Dir $WorkDir
$stage = Join-Path $WorkDir 'oracle-sdk'
$include = Join-Path $stage 'include'
$lib = Join-Path $stage 'lib'
Prepare-Dir $stage; Prepare-Dir $include; Prepare-Dir $lib

if ($PSCmdlet.ParameterSetName -eq 'Home') {
    $OracleHome = Require-Path $OracleHome
    $ok = Prepare-FromDirectory -Directory $OracleHome -IncludeDir $include -LibDir $lib
} else {
    $OracleZip = Require-Path $OracleZip
    $media = Join-Path $WorkDir 'oracle-media'
    Prepare-Dir $media
    Write-Host "Extracting Oracle installation ZIP: $OracleZip"
    Expand-Archive -LiteralPath $OracleZip -DestinationPath $media -Force
    $ok = Prepare-FromDirectory -Directory $media -IncludeDir $include -LibDir $lib
    if (-not $ok) {
        Write-Host 'oci.h / oci.lib not present as normal files; checking Oracle Universal Installer JARs...'
        $ok = Prepare-FromOUIArchives -MediaDir $media -IncludeDir $include -LibDir $lib
    }
}

if (-not $ok -or -not (Test-Path (Join-Path $include 'oci.h')) -or
        -not (Test-Path (Join-Path $lib 'oci.lib'))) {
    throw @'
Oracle SDK files were not found in a usable form.
The full Oracle Client installer ZIP may require running Oracle Universal Installer,
including the SDK / OCI development components. After installation run:
  .\Build-OCI8.ps1 -OracleHome 'C:\app\...\client_1'
Expected inside Oracle Home: oci\include\oci.h and oci\lib\msvc\oci.lib
'@
}

$tar = Get-Command tar.exe -ErrorAction SilentlyContinue
if (-not $tar) { throw 'tar.exe not found. Use Windows 10/11 (or install bsdtar) on the BUILD machine.' }
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    Write-Warning 'git.exe not found. BuildPhpExtension may require Git.'
}
$modulePath = 'BuildPhpExtension'
if ($SkipModuleInstall) {
    if (-not (Get-Module -ListAvailable -Name BuildPhpExtension)) {
        throw 'BuildPhpExtension is not installed.'
    }
} else {
    # Use an exact upstream revision, avoiding intermittent PSGallery download
    # failures and changes to private helper APIs between runner jobs.
    $builderRef = '68dc945d9509c41b72332c74c8b99731bb75bc25'
    $tools = Join-Path $WorkDir 'build-tools'
    Prepare-Dir $tools
    $builderZip = Join-Path $tools 'php-windows-builder.zip'
    $downloaded = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/php/php-windows-builder/archive/$builderRef.zip" -OutFile $builderZip
            $downloaded = $true
            break
        } catch {
            if ($attempt -eq 3) { throw }
            Start-Sleep -Seconds (5 * $attempt)
        }
    }
    if (-not $downloaded) { throw 'Cannot download the pinned PHP build helper.' }
    Expand-Archive -LiteralPath $builderZip -DestinationPath $tools -Force
    $modulePath = Join-Path $tools "php-windows-builder-$builderRef\extension\BuildPhpExtension\BuildPhpExtension.psd1"
    Write-Host "Using PHP build helper revision $builderRef"
}
$builderModule = Import-Module $modulePath -Force -ErrorAction Stop -PassThru
# Upstream hard-codes OCI8 to oci8_19. Override only this imported module's
# private name detector in memory, so its configure/link/package checks target
# the requested 11g variant. No installed tooling is modified on disk.
& $builderModule {
    if (-not (Get-Command Get-ExtensionName -ErrorAction SilentlyContinue)) {
        throw 'Unsupported BuildPhpExtension: private name detector changed.'
    }
    Set-Item -Path Function:script:Get-ExtensionName -Value { return 'oci8_11g' }
}
$env:RUN_TESTS = 'false' # Database-backed upstream tests require a separate Oracle DB.
$env:AUTO_DETECT_ARGS = 'false'
$env:AUTO_DETECT_LIBS = 'false'
$env:ARTIFACT_NAMING_SCHEME = 'pecl'
if (-not (Get-Command Invoke-PhpBuildExtension -ErrorAction SilentlyContinue)) {
    throw 'Invoke-PhpBuildExtension command missing after module import.'
}

$archiveDir = Join-Path $WorkDir 'downloads'; Prepare-Dir $archiveDir
$tarPath = Join-Path $archiveDir "oci8-$ociVersion.tgz"
if (-not (Test-Path $tarPath)) {
    Write-Host "Downloading official PECL OCI8 $ociVersion source..."
    Invoke-WebRequest -Uri "https://pecl.php.net/get/oci8-$ociVersion.tgz" -OutFile $tarPath
}
$srcPack = Join-Path $WorkDir 'oci8-source'; Prepare-Dir $srcPack
& $tar.Source -xf $tarPath -C $srcPack
if ($LASTEXITCODE -ne 0) { throw 'Cannot extract OCI8 source tarball.' }
$source = Join-Path $srcPack "oci8-$ociVersion"
if (-not (Test-Path (Join-Path $source 'config.w32'))) {
    throw "Missing config.w32 after extracting PECL package: $source"
}

$resultsDir = Join-Path $WorkDir 'dist'; Prepare-Dir $resultsDir
$failures = New-Object System.Collections.Generic.List[string]
foreach ($php in $PhpVersions) {
    foreach ($ts in $ThreadSafety) {
        $targetName = "php$php-$ts-x64"
        $build = Join-Path $WorkDir "build-$targetName"
        Write-Host "`n=== Building OCI8 $ociVersion for PHP $php ($ts x64) ===" -ForegroundColor Cyan
        try {
            if (Test-Path $build) { Remove-Item -LiteralPath $build -Recurse -Force }
            Prepare-Dir $build
            Copy-Item -Path (Join-Path $source '*') -Destination $build -Recurse -Force
            Push-Location $build
            try {
                # Windows config.w32 accepts <SDK path>,shared for oci8-11g.
                $argsText = "--with-oci8-11g=$stage,shared"
                Invoke-PhpBuildExtension -PhpVersion $php -Arch x64 -Ts $ts -Args $argsText
            }
            finally { Pop-Location }
            # The helper returns artifact ZIPs, not loose build DLLs.
            $artifactDir = Join-Path $build 'artifacts'
            if (Test-Path -LiteralPath $artifactDir) {
                $packages = @(Get-ChildItem -LiteralPath $artifactDir -Filter '*.zip' -File)
                $packageIndex = 0
                foreach ($package in $packages) {
                    $packageIndex++
                    Expand-Archive -LiteralPath $package.FullName -DestinationPath (Join-Path $build "unpacked-$packageIndex") -Force
                }
            }
            $built = @(Get-ChildItem -LiteralPath $build -Filter 'php_oci8_11g.dll' -File -Recurse |
                Sort-Object LastWriteTime -Descending)
            if ($built.Count -eq 0) { throw 'No php_oci8_11g.dll was produced.' }
            $out = Join-Path $resultsDir $targetName
            Prepare-Dir $out
            $dest = Join-Path $out 'php_oci8_11g.dll'
            Copy-Item -LiteralPath $built[0].FullName -Destination $dest -Force
            $hash = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash
            Set-Content -Path (Join-Path $out 'SHA256.txt') -Value "SHA256 $hash  php_oci8_11g.dll"
            Write-Host "OK: $dest" -ForegroundColor Green
        }
        catch {
            $msg = "$targetName : $_"
            $failures.Add($msg)
            Write-Warning $msg
        }
    }
}
Write-Host "`nOutput: $resultsDir"
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Warning $_ }
    throw "$($failures.Count) build(s) failed; check messages above and build logs."
}
Write-Host 'All requested builds completed.' -ForegroundColor Green
