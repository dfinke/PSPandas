<#
.SYNOPSIS
Installs the local PSPandas checkout into a PowerShell module path.

.DESCRIPTION
Copies the module files from this repository into a PSPandas module directory
using Robocopy, then imports the installed manifest to verify the result.
The source checkout is not modified. The default destination is the first
existing path in $env:PSModulePath; use -Destination to choose another path.

.PARAMETER Destination
The module directory to receive the installed PSPandas files. If omitted,
the first existing PowerShell module path is used and a PSPandas child folder
is created beneath it.

.EXAMPLE
& ./InstallModule.ps1

.EXAMPLE
& ./InstallModule.ps1 -Destination "$HOME\Documents\PowerShell\Modules\PSPandas"
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $Destination
)

Set-StrictMode -Version Latest

$sourcePath = (Resolve-Path -LiteralPath $PSScriptRoot -ErrorAction Stop).Path

if ([string]::IsNullOrWhiteSpace($Destination)) {
    $moduleRoot = $env:PSModulePath -split [regex]::Escape([IO.Path]::PathSeparator) |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } |
        Select-Object -First 1

    if (-not $moduleRoot) {
        throw 'No existing PowerShell module path was found. Supply -Destination explicitly.'
    }

    $Destination = Join-Path -Path $moduleRoot -ChildPath 'PSPandas'
}
else {
    $Destination = [IO.Path]::GetFullPath($Destination)
}

New-Item -ItemType Directory -Path $Destination -Force | Out-Null

# Keep Robocopy for reliable Windows module installation, while excluding
# repository-only content and preserving the module's license and metadata.
& robocopy $sourcePath $Destination /E /R:2 /W:2 `
    /XD '.git' '.github' '.vscode' 'docs' 'examples' 'tests' 'TestResults' 'coverage' `
    /XF '.gitignore' 'InstallModule.ps1' 'PublishToGallery.ps1' 'TODO.md' `
    'README.original.md' 'appveyor.yml' 'azure-pipelines.yml' 2>&1 | Out-Host

$robocopyExitCode = $LASTEXITCODE
if ($robocopyExitCode -gt 7) {
    throw "Robocopy failed with exit code $robocopyExitCode."
}

$installedManifest = Join-Path -Path $Destination -ChildPath 'PSPandas.psd1'
Test-ModuleManifest -Path $installedManifest -ErrorAction Stop | Out-Null
Import-Module $installedManifest -Force -ErrorAction Stop

Write-Output "PSPandas installed at $Destination"
