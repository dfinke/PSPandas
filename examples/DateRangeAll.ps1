<#
.SYNOPSIS
Shows every Get-PSDateRange frequency and range-shape supported by PSPandas.

.DESCRIPTION
Runs examples for bounded ranges, start/end plus periods, endpoint
inclusion, and DateOnly output. Results are displayed as ISO-formatted rows
so the generated values are easy to compare across frequencies.
#>

$modulePath = Join-Path $PSScriptRoot '..\PSPandas.psd1'
Import-Module $modulePath -Force

Clear-Host

function Show-DateRangeExample {
    param(
        [string]$Name,
        [object[]]$Values
    )

    "`n--- $Name ---"
    $Values | ForEach-Object {
        $value = $_
        $formatted = if ($value -is [System.DateOnly]) {
            $value.ToString('yyyy-MM-dd')
        }
        else {
            $value.ToString('yyyy-MM-ddTHH:mm:ss')
        }

        [pscustomobject]@{
            Value = $formatted
            Type  = $value.GetType().Name
        }
    } | Format-Table -AutoSize
}

# Bounded start/end range with both endpoints included by default.
Show-DateRangeExample 'Day / D' @(
    Get-PSDateRange -Start '2026-01-01' -End '2026-01-03'
)

Show-DateRangeExample 'Hour / h' @(
    Get-PSDateRange -Start '2026-01-01T08:00:00' -Periods 4 -Frequency Hour
)

Show-DateRangeExample 'Week / W' @(
    Get-PSDateRange -Start '2026-01-01' -Periods 4 -Frequency W -DateOnly
)

Show-DateRangeExample 'BusinessDay / B' @(
    Get-PSDateRange -End '2026-01-05' -Periods 5 -Frequency BusinessDay -DateOnly
)

Show-DateRangeExample 'MonthStart / MS' @(
    Get-PSDateRange -Start '2026-01-15' -Periods 4 -Frequency MS -DateOnly
)

Show-DateRangeExample 'MonthEnd / ME' @(
    Get-PSDateRange -Start '2026-01-15' -Periods 4 -Frequency MonthEnd -DateOnly
)

Show-DateRangeExample 'QuarterStart / QS' @(
    Get-PSDateRange -Start '2026-02-15' -Periods 4 -Frequency QS -DateOnly
)

Show-DateRangeExample 'YearStart / YS' @(
    Get-PSDateRange -Start '2026-06-01' -Periods 4 -Frequency YearStart -DateOnly
)

Show-DateRangeExample 'Inclusive Left' @(
    Get-PSDateRange -Start '2026-01-01' -End '2026-01-04' -Inclusive Left -DateOnly
)

Show-DateRangeExample 'Inclusive Right' @(
    Get-PSDateRange -Start '2026-01-01' -End '2026-01-04' -Inclusive Right -DateOnly
)

Show-DateRangeExample 'Inclusive Neither' @(
    Get-PSDateRange -Start '2026-01-01' -End '2026-01-04' -Inclusive Neither -DateOnly
)
