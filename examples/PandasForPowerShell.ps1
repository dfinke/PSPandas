<#
.SYNOPSIS
Runs the PSPandas tutorial from start to finish.

.DESCRIPTION
Uses the repository retail-order data to demonstrate loading, inspection,
filtering, calculated columns, indexed column operations, summaries, pivots,
crosstabs, joins, concatenation, date ranges, and profiling.

.EXAMPLE
& ./examples/PandasForPowerShell.ps1
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$modulePath = Join-Path $PSScriptRoot '..\PSPandas.psd1'
$ordersPath = Join-Path $PSScriptRoot 'data\RetailOrders.csv'
Import-Module $modulePath -Force

function Show-Section {
    param([Parameter(Mandatory)][string]$Title)
    "`n=== $Title ==="
}

Show-Section 'Load data'
$orders = Import-PSDataFrame -Path $ordersPath
$orders | Get-PSDataFrameHead -Count 5 | Format-Table -AutoSize

Show-Section 'Inspect the frame'
$orders | Get-PSDataFrameInfo
$orders | Get-PSDataFrameHead -Count 3 | Format-Table -AutoSize
$orders | Get-PSDataFrameColumn

Show-Section 'Select and filter'
$profitable = $orders |
    Find-PSDataFrame { $_.Profit -gt 500 } |
    Select-PSDataFrame -Property 'Order ID', 'Region', 'Category', Sales, Profit
$profitable | ConvertFrom-PSDataFrame | Select-Object -First 8 | Format-Table -AutoSize

Show-Section 'Add a calculated column'
$orders = $orders |
    Add-PSDataFrameColumn -Name Year -Expression { $_.'Order Date'.Year }
$orders | Get-PSDataFrameHead -Count 3 |
    Format-Table -Property @('Order ID', 'Order Date', 'Year', 'Sales') -AutoSize

Show-Section 'Indexed column operations'
[pscustomobject]@{
    SalesSum     = $orders['Sales'].Sum()
    SalesAverage = $orders['Sales'].Average()
    FirstSales   = $orders['Sales'][0..2]
}

Show-Section 'Summarize'
$byRegion = $orders |
    Summarize -By Region -Count 'Order ID' -Sum Sales, Profit
$byRegion | ConvertFrom-PSDataFrame | Format-Table -AutoSize

Show-Section 'Pivot'
$orders |
    Pivot -Index Region -Columns Category -Values Sales -Aggregate Sum -FillValue 0

Show-Section 'Crosstab'
$orders |
    Crosstab -Index Region -Columns Segment -FillValue 0

Show-Section 'Join'
$customers = @(
    $orders.Rows |
        Select-Object -Property 'Customer ID', 'Customer Name' -Unique |
        Select-Object -First 5 |
        ForEach-Object {
            [pscustomobject][ordered]@{
                'Customer ID' = $_.'Customer ID'
                CustomerName  = $_.'Customer Name'
            }
        }
) | ConvertTo-PSDataFrame

$ordersForJoin = $orders |
    Select-PSDataFrame -Property 'Order ID', 'Customer ID', Region, Sales

Join-PSDataFrame -Left $ordersForJoin -Right $customers -On 'Customer ID' -JoinType Left |
    Get-PSDataFrameHead -Count 5 |
    Format-Table -AutoSize

Show-Section 'Concat'
$firstHalf = $orders | Get-PSDataFrameHead -Count 3 | ConvertTo-PSDataFrame
$secondHalf = $orders | Get-PSDataFrameTail -Count 3 | ConvertTo-PSDataFrame
$firstHalf, $secondHalf | Concat | Get-PSDataFrameInfo

Show-Section 'Date range'
Get-PSDateRange -Start '2025-01-01' -Periods 6 -Frequency MonthStart -DateOnly |
    ForEach-Object { [pscustomobject]@{ MonthStart = $_ } } |
    Format-Table -AutoSize

Show-Section 'Profile'
$orders | Describe

Show-Section 'Profile rows in a pipeline'
$orders |
    Describe -AsRows |
    Where-Object Type -eq 'Numeric' |
    Select-Object Column, Type, Minimum, Maximum, Average, Sum |
    Format-Table -AutoSize
