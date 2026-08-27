<#
.SYNOPSIS
Runs the PSPandas tutorial from start to finish.

.DESCRIPTION
Uses the repository retail-order data to answer a practical question: which
regions, categories, and customer segments are driving sales and profit?
The script demonstrates the complete analysis from loading through profiling.

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

function Show-FrameRows {
    param(
        [Parameter(Mandatory)][object]$DataFrame,
        [int]$Count = 5
    )

    $DataFrame |
        ConvertFrom-PSDataFrame |
        Select-Object -First $Count |
        Format-Table -AutoSize
}

Show-Section 'Business question'
'Which regions, categories, and customer segments are driving sales and profit?'
'We will load the order lines, create useful dimensions, compare groups, and build a compact report.'

Show-Section 'Load data'
$orders = Import-PSDataFrame -Path $ordersPath
Show-FrameRows -DataFrame $orders -Count 5

Show-Section 'Inspect the frame'
$orders | Get-PSDataFrameInfo
$orders | Get-PSDataFrameColumn

Show-Section 'Select and filter'
$orders |
    Find-PSDataFrame { $_.Profit -gt 500 } |
    Select-PSDataFrame -Property 'Order ID', Region, Category, Sales, Profit |
    Set-PSDataFrameOrder -Property Profit -Descending |
    ConvertFrom-PSDataFrame |
    Select-Object -First 8 |
    Format-Table -AutoSize

Show-Section 'Add analytical columns'
$orders = $orders |
    Add-PSDataFrameColumn -Name Year -Expression { $_.'Order Date'.Year } |
    Add-PSDataFrameColumn -Name ProfitMargin -Expression {
        if ($_.Sales -eq 0) { $null } else { $_.Profit / $_.Sales }
    }
$orders | Get-PSDataFrameHead -Count 3 |
    Format-Table -Property @('Order ID', 'Order Date', 'Year', 'Sales', 'ProfitMargin') -AutoSize

Show-Section 'Indexed column operations'
[pscustomobject]@{
    SalesSum     = $orders['Sales'].Sum()
    SalesAverage = $orders['Sales'].Average()
    FirstSales   = $orders['Sales'][0..2]
}

Show-Section 'Summarize by region'
$byRegion = $orders |
    Summarize -By Region -Count 'Order ID' -Sum Sales, Profit
$byRegion | ConvertFrom-PSDataFrame | Format-Table -AutoSize

$bestRegion = $byRegion.Rows |
    Sort-Object Sum_Profit -Descending |
    Select-Object -First 1
"Top profit region: $($bestRegion.Region) ($($bestRegion.Sum_Profit))"

Show-Section 'Pivot sales by region and category'
$categoryPivot = $orders |
    Pivot -Index Region -Columns Category -Values Sales -Aggregate Sum -FillValue 0
$categoryPivot

Show-Section 'Crosstab region and customer segment'
$orders |
    Crosstab -Index Region -Columns Segment -FillValue 0

Show-Section 'Join a customer dimension'
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

Show-Section 'Concat two frame slices'
$firstHalf = $orders | Get-PSDataFrameHead -Count 3 | ConvertTo-PSDataFrame
$secondHalf = $orders | Get-PSDataFrameTail -Count 3 | ConvertTo-PSDataFrame
$firstHalf, $secondHalf | Concat | Get-PSDataFrameInfo

Show-Section 'Create a calendar range'
Get-PSDateRange -Start '2025-01-01' -Periods 6 -Frequency MonthStart -DateOnly |
    ForEach-Object { [pscustomobject]@{ MonthStart = $_ } } |
    Format-Table -AutoSize

Show-Section 'Profile the source columns'
$orders | Describe

Show-Section 'Use profile rows in a pipeline'
$orders |
    Describe -AsRows |
    Where-Object Type -eq 'Numeric' |
    Select-Object Column, Type, Minimum, Maximum, Average, Sum |
    Format-Table -AutoSize
