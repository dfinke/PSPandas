<#
.SYNOPSIS
Demonstrates constructing a DataFrame from column-oriented vectors.

.DESCRIPTION
Builds the age, score, reaction-time, and experimental-group dataset using
ConvertTo-PSDataFrame -ColumnData, then uses indexed columns and grouped
summaries without manually transposing the vectors into rows.

.EXAMPLE
& ./examples/ColumnData.ps1
#>

Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$age = 17, 19, 21, 37, 18, 19, 47, 18, 19
$score = 12, 10, 11, 15, 16, 14, 25, 21, 29
$rt = 3.552, 1.624, 6.431, 7.132, 2.925, 4.662, 3.634, 3.635, 5.234
$group = 'test', 'test', 'test', 'test', 'test', 'control', 'control', 'control', 'control'

$data = ConvertTo-PSDataFrame -ColumnData ([ordered]@{
    age   = $age
    score = $score
    rt    = $rt
    group = $group
})

'DataFrame constructed directly from column vectors:'
$data

'Scalar column operations:'
[pscustomobject][ordered]@{
    AverageAge   = $data['age'].Average()
    MaximumScore = $data['score'].Max()
    AverageRT    = $data['rt'].Average()
} | Format-List

'Grouped summary:'
$data |
    Summarize -By group -Average age, score, rt |
    ConvertFrom-PSDataFrame |
    Format-Table
