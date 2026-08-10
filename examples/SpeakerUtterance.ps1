<#
.SYNOPSIS
Builds a speaker and utterance DataFrame from column-oriented vectors.

.DESCRIPTION
Demonstrates the PowerShell equivalent of a pandas DataFrame constructed from
two ordered vectors, while preserving the declared column order.

.EXAMPLE
& ./examples/SpeakerUtterance.ps1
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

$speechData
