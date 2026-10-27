#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)] [string] $PhpExe,
    [Parameter(Mandatory=$true)] [string] $Dll,
    [Parameter(Mandatory=$true)] [string] $OracleBin
)
$ErrorActionPreference = 'Stop'
foreach ($p in @($PhpExe,$Dll,$OracleBin)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Not found: $p" }
}
$PhpExe = (Resolve-Path -LiteralPath $PhpExe).Path
$Dll = (Resolve-Path -LiteralPath $Dll).Path
$OracleBin = (Resolve-Path -LiteralPath $OracleBin).Path
$oldPath = $env:PATH
try {
    $env:PATH = "$OracleBin;$oldPath"
    Write-Host 'Checking PHP version, architecture, thread safety and build signature:'
    & $PhpExe -n -i | Select-String 'PHP Version|Architecture|Thread Safety|PHP Extension Build'
    if ($LASTEXITCODE -ne 0) { throw "PHP returned exit code $LASTEXITCODE" }
    Write-Host "`nLoading OCI8 using: $Dll"
    & $PhpExe -n -d "extension=$Dll" --ri oci8
    if ($LASTEXITCODE -ne 0) { throw "OCI8 load test failed (exit $LASTEXITCODE)" }
    & $PhpExe -n -d "extension=$Dll" -r 'if (!extension_loaded("oci8") || !function_exists("oci_connect")) { exit(1); } echo "OCI8 ", phpversion("oci8"), PHP_EOL;'
    if ($LASTEXITCODE -ne 0) { throw 'OCI8 extension/function assertion failed.' }
    Write-Host 'OCI8 loaded successfully.' -ForegroundColor Green
}
finally { $env:PATH = $oldPath }
