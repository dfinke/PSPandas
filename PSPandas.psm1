<#
.SYNOPSIS
Loads the PSPandas module implementation and exports its public command surface.

.DESCRIPTION
Loads private types and helpers before public commands, then exports only the
canonical functions and documented convenience or compatibility aliases listed
by the module manifest.
#>

Set-StrictMode -Version Latest

$privateFiles = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'src\Private') -Filter '*.ps1' -File | Sort-Object Name
foreach ($file in $privateFiles) {
    . $file.FullName
}

$publicFiles = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'src\Public') -Filter '*.ps1' -File | Sort-Object Name
foreach ($file in $publicFiles) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'ConvertTo-PSDataFrame',
    'Import-PSDataFrame',
    'ConvertFrom-PSDataFrame',
    'Get-PSDataFrameProfile',
    'Get-PSDataFrameInfo',
    'Get-PSDataFrameHead',
    'Get-PSDataFrameTail',
    'Get-PSDataFrameColumn',
    'Find-PSDataFrame',
    'Select-PSDataFrame',
    'Set-PSDataFrameOrder',
    'Add-PSDataFrameColumn',
    'Group-PSDataFrame',
    'Measure-PSDataFrame',
    'ConvertTo-PSDataFrameWide',
    'ConvertTo-PSDataFrameCrosstab',
    'ConvertTo-PSDataFrameConcat',
    'Join-PSDataFrame'
) -Alias @(
    'Where-PSDF',
    'Where-PSDataFrame',
    'Select-PSDF',
    'Sort-PSDF',
    'Sort-PSDataFrame',
    'Add-PSDFColumn',
    'Group-PSDF',
    'Summarize-PSDF',
    'Summarize-PSDataFrame',
    'Summarize',
    'Pivot',
    'Pivot-PSDataFrame',
    'Crosstab-PSDataFrame',
    'Crosstab',
    'xtab',
    'Concat-PSDataFrame',
    'Concat',
    'ctdf',
    'Describe',
    'Join-PSDF'
)
