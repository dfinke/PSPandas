<#
.SYNOPSIS
Builds a DataFrame from several generated date ranges.

.DESCRIPTION
Demonstrates how Get-PSDateRange can create equal-length typed vectors for
ConvertTo-PSDataFrame -ColumnData. The resulting frame has one row per day,
with a daily range, month-start markers, and business-day values.
#>

$modulePath = Join-Path $PSScriptRoot '..\PSPandas.psd1'
Import-Module $modulePath -Force

$data = [ordered]@{
    Range       = @(Get-PSDateRange -Start '2024-01-01' -End '2024-01-12')
    MonthStart  = @(Get-PSDateRange -Start '2024-01-01' -Periods 12 -Frequency MonthStart -DateOnly)
    BusinessDay = @(Get-PSDateRange -End '2024-01-05' -Periods 12 -Frequency BusinessDay)
}

$df = ConvertTo-PSDataFrame -ColumnData $data

'Generated calendar frame:'
$df

'Schema and types:'
$df | Get-PSDataFrameInfo
$df.Rows[0].PSObject.Properties | ForEach-Object {
    [pscustomobject]@{
        Column = $_.Name
        Type   = if ($null -eq $_.Value) { 'null' } else { $_.Value.GetType().Name }
    }
}

'First three rows:'
$df.Rows | Select-Object -First 3 | Format-Table

'Month starts that fall on a weekday:'
$df.Rows |
    Where-Object { $_.MonthStart.DayOfWeek -notin @([DayOfWeek]::Saturday, [DayOfWeek]::Sunday) } |
    Select-Object -First 3 Range, MonthStart, BusinessDay |
    Format-Table
