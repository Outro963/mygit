# MyGit build script (g++ direct, no CMake needed)
# Usage:  .\build.ps1
# ASCII-only messages: Windows PowerShell 5.1 mis-decodes UTF-8 .ps1 without BOM.

$ErrorActionPreference = 'Stop'
$root   = $PSScriptRoot
$srcDir = Join-Path $root 'src'
$outDir = Join-Path $root 'build'
$exe    = Join-Path $outDir 'mygit.exe'

if (-not (Test-Path $srcDir)) { Write-Host "ERROR: src\ not found at $srcDir" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

$gxx = (Get-Command g++ -ErrorAction SilentlyContinue).Source
if (-not $gxx) {
    Write-Host "ERROR: g++ not found on PATH." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install a toolchain first (see 计划-C++版16周.md section 6):"
    Write-Host "  A) MSYS2 UCRT64 : pacman -S mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-gdb"
    Write-Host "                      then add C:\msys64\ucrt64\bin to PATH"
    Write-Host "  B) Visual Studio: install 'Desktop development with C++' (use cl.exe, not this script)"
    Write-Host "  C) w64devkit    : unzip, add its bin\ to PATH"
    exit 1
}

$sources = @(Get-ChildItem -Path $srcDir -Recurse -Filter *.cpp | ForEach-Object { $_.FullName })
if ($sources.Count -eq 0) { Write-Host "ERROR: no .cpp files in src\" -ForegroundColor Red; exit 1 }

Write-Host ("Compiling {0} source file(s) ..." -f $sources.Count) -ForegroundColor Cyan
$cxxargs = @('-std=c++17', '-Wall', '-Wextra', '-g', '-O0', '-I', (Join-Path $root 'include')) + $sources + @('-o', $exe)

& $gxx @cxxargs
if ($LASTEXITCODE -ne 0) { Write-Host "BUILD FAILED" -ForegroundColor Red; exit $LASTEXITCODE }

Write-Host ("OK -> {0}" -f $exe) -ForegroundColor Green
