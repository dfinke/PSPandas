<#
.SYNOPSIS
Builds a frequency cross-tabulation from speaker and utterance data.

.DESCRIPTION
Demonstrates the Crosstab convenience alias and its row and column totals.

.EXAMPLE
& ./examples/Crosstab.ps1
#>

Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$speechData = ConvertTo-PSDataFrame -ColumnData ([ordered]@{
    speaker = @(
        'upsy-daisy', 'upsy-daisy', 'upsy-daisy', 'upsy-daisy'
        'tombliboo', 'tombliboo'
        'makka-pakka', 'makka-pakka', 'makka-pakka', 'makka-pakka'
    )
    utterance = @(
        'pip', 'pip', 'onk', 'onk'
        'ee', 'oo'
        'pip', 'pip', 'onk', 'onk'
    )
})

$speechData | Crosstab -Index speaker -Columns utterance -Margins -FillValue 0

'Normalized frequency by speaker (each row sums to 1):'
$speechData | Crosstab -Index speaker -Columns utterance -Normalize Index

'Normalized frequency as percentage points (rows remain numeric):'
$speechData | Crosstab -Index speaker -Columns utterance -Normalize Index -Percent
