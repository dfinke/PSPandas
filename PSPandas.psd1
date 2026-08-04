@{
    RootModule        = 'PSPandas.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'e4c56e9a-6ccf-4de7-9ae9-7c8dddf4e8c5'
    Author            = 'PSPandas contributors'
    CompanyName       = 'Community'
    Copyright         = '(c) PSPandas contributors. All rights reserved.'
    Description       = 'A lightweight, pipeline-friendly PowerShell data-frame library.'
    PowerShellVersion = '7.0'
    FormatsToProcess  = @('PSPandas.format.ps1xml')
    FunctionsToExport = @(
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
        'Describe',
        'Join-PSDF'
    )
    PrivateData       = @{
        PSData = @{
            Tags = @('PowerShell', 'dataframe', 'pipeline', 'data-manipulation')
        }
    }
}
