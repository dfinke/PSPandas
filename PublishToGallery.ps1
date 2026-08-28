<#
.SYNOPSIS
Publishes the PSPandas module to a PowerShell repository.

.DESCRIPTION
Validates the local PSPandas module manifest and publishes this module
directory. The API key can be supplied as a parameter or through the
PSGalleryApiKey environment variable. Use -WhatIf to validate the command
without publishing.

.PARAMETER NuGetApiKey
The API key for the target PowerShell repository.

.PARAMETER Repository
The registered PowerShell repository to publish to. Defaults to PSGallery.

.EXAMPLE
& ./PublishToGallery.ps1 -NuGetApiKey $env:PSGalleryApiKey -WhatIf

.EXAMPLE
& ./PublishToGallery.ps1 -NuGetApiKey $env:PSGalleryApiKey
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $NuGetApiKey = $env:PSGalleryApiKey,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $Repository = 'PSGallery'
)

Set-StrictMode -Version Latest

$manifestPath = Join-Path -Path $PSScriptRoot -ChildPath 'PSPandas.psd1'
$manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop

if ([string]::IsNullOrWhiteSpace($NuGetApiKey)) {
    throw 'A PowerShell Gallery API key is required. Supply -NuGetApiKey or set the PSGalleryApiKey environment variable.'
}

$target = "$( $manifest.Name ) $($manifest.Version) to $Repository"
if ($PSCmdlet.ShouldProcess($target, 'Publish module')) {
    Publish-Module `
        -Path $PSScriptRoot `
        -Repository $Repository `
        -NuGetApiKey $NuGetApiKey `
        -ErrorAction Stop
}
