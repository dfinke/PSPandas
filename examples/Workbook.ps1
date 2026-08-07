<#
.SYNOPSIS
Demonstrates importing and navigating a multi-sheet workbook.

.DESCRIPTION
Loads the checked-in retail workbook, lists its ordered worksheets, accesses a
sheet through a tab-completable property, and profiles another by index.

.EXAMPLE
& ./examples/Workbook.ps1
#>

Import-Module ImportExcel -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$path = Join-Path $PSScriptRoot 'data\RetailWorkbook.xlsx'
$book = Import-PSDataFrame $path -AsWorkbook

'Workbook overview:'
$book

'Worksheets in workbook order:'
$book.Worksheets.Names

'Summarize the standalone Sales worksheet through its tab-completable property:'
$book.Sales |
    Summarize -By Region -Sum Sales, Profit |
    ConvertFrom-PSDataFrame |
    Format-Table

'Profile another worksheet through the indexed collection:'
$book.Worksheets['Returns'] |
    Describe -AsRows |
    Format-Table Column, Type, RowCount, NullCount, DistinctCount
