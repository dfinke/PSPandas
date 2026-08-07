<#
.SYNOPSIS
Demonstrates joining related workbook worksheets as DataFrames.

.DESCRIPTION
Joins order lines to customer, product, and optional return data, validates row
and sales totals, and pivots the reconstructed analytical frame.

.EXAMPLE
& ./examples/WorkbookJoins.ps1
#>

Import-Module ImportExcel -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$path = Join-Path $PSScriptRoot 'data\RetailWorkbook.xlsx'
$book = Import-PSDataFrame $path -AsWorkbook

# Build an analysis-ready frame from the normalized workbook sheets.
$withCustomers = Join-PSDataFrame `
    -Left $book.OrderLines `
    -Right $book.Customers `
    -On 'Customer ID' `
    -JoinType Left

$withProducts = Join-PSDataFrame `
    -Left $withCustomers `
    -Right $book.Products `
    -On 'Product ID' `
    -JoinType Left

$enriched = Join-PSDataFrame `
    -Left $withProducts `
    -Right $book.Returns `
    -On 'Order ID' `
    -JoinType Left

if ($enriched.Count -ne $book.OrderLines.Count) {
    throw 'The joins unexpectedly changed the number of order lines.'
}

if ($enriched['Sales'].Sum() -ne $book.Sales['Sales'].Sum()) {
    throw 'The joined and standalone sales totals do not match.'
}

'Joined rows (returns remain optional through the left join):'
$enriched |
    Get-PSDataFrameHead -Count 5 |
    Format-Table 'Order ID', 'Customer Name', Region, Category, Sales, 'Return Reason'

'Sales reconstructed from OrderLines + Customers + Products:'
$enriched |
    Pivot -Index Region, State -Columns Category -Values Sales -Aggregate Sum `
        -Margins -Sort -Outline -Grid
