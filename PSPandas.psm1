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
    'ConvertFrom-PSDataFrame',
    'Get-PSDataFrameProfile',
    'Get-PSDataFrameInfo',
    'Get-PSDataFrameHead',
    'Get-PSDataFrameColumn',
    'Find-PSDataFrame',
    'Select-PSDataFrame',
    'Set-PSDataFrameOrder',
    'Add-PSDataFrameColumn',
    'Group-PSDataFrame',
    'Measure-PSDataFrame',
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
    'Describe',
    'Join-PSDF'
)
