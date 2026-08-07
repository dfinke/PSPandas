<#
.SYNOPSIS
Demonstrates analyzing a standalone worksheet from a workbook.

.DESCRIPTION
Uses the denormalized Sales worksheet directly for profiling, summaries, and a
hierarchical pivot without joining other sheets.

.EXAMPLE
& ./examples/WorkbookStandalone.ps1
#>

Import-Module ImportExcel -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$path = Join-Path $PSScriptRoot 'data\RetailWorkbook.xlsx'
$book = Import-PSDataFrame $path -AsWorkbook

'Workbook sheets (also discoverable with Ctrl+Space after $book.):'
$book.Worksheets.Names

$sales = $book.Sales

'Standalone Sales worksheet profile:'
$sales |
    Describe -AsRows |
    Where-Object Column -in 'Region', 'Category', 'Sales', 'Profit' |
    Format-Table Column, Type, RowCount, DistinctCount, Minimum, Maximum, Average, Sum

'Standalone regional summary—no joins required:'
$sales |
    Summarize -By Region -Sum Sales, Profit |
    Set-PSDataFrameOrder Sum_Sales -Descending

'Standalone sales pivot:'
$sales |
    Pivot -Index Region, State -Columns Category -Values Sales -Aggregate Sum `
        -Margins -Sort -Outline -Grid
