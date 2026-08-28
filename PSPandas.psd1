@{
    RootModule        = 'PSPandas.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'e4c56e9a-6ccf-4de7-9ae9-7c8dddf4e8c5'
    Author            = 'PSPandas contributors'
    CompanyName       = 'Community'
    Copyright         = '(c) 2026 PSPandas contributors'
    Description       = 'A PowerShell-native, pipeline-friendly data-frame library inspired by the practical parts of pandas.'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    FormatsToProcess  = @('PSPandas.format.ps1xml')
    FunctionsToExport = @(
        'ConvertTo-PSDataFrame',
        'Import-PSDataFrame',
        'ConvertFrom-PSDataFrame',
        'Get-PSDataFrameProfile',
        'Get-PSDataFrameInfo',
        'Get-PSDataFrameHead',
        'Get-PSDataFrameTail',
        'Get-PSDataFrameColumn',
        'Get-NormalRandom',
        'Get-RandomInt',
        'Get-PSDateRange',
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
    )
    AliasesToExport   = @(
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
    PrivateData       = @{
        PSData = @{
            Tags         = @('PowerShell', 'dataframe', 'pipeline', 'data-manipulation', 'pandas', 'csv', 'excel')
            LicenseUri   = 'https://github.com/dfinke/PSPandas/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/dfinke/PSPandas'
            ReleaseNotes = 'Initial PowerShell Gallery release with typed imports, data-frame transformations, summaries, pivots, crosstabs, profiling, joins, concat, and date ranges.'
        }
    }
}
