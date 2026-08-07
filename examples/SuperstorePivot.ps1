Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$readerManifest = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'PSFlatFile\PSFlatFile.psd1'
if (-not (Test-Path -LiteralPath $readerManifest)) {
    throw 'This example requires the PSFlatFile repository beside PSPandas.'
}
Import-Module $readerManifest -Force

$dataPath = Join-Path $PSScriptRoot 'data\RetailOrders.csv'
$orders = Import-PSDataFrame $dataPath

'Dataset profile:'
$orders |
    Describe -AsRows |
    Where-Object Column -in 'Order Date', 'Region', 'Category', 'Sales', 'Quantity', 'Discount', 'Profit' |
    Format-Table Column, Type, RowCount, DistinctCount, Minimum, Maximum, Average, Sum

'Sales by region, state, and category:'
$orders |
    Pivot -Index Region, State -Columns Category -Values Sales -Aggregate Sum `
        -Margins -Outline -Grid

'Sales, profit, and quantity by region and category:'
$orders |
    Pivot -Index Region -Columns Category -Aggregate ([ordered]@{
        Sales    = 'Sum'
        Profit   = 'Sum'
        Quantity = 'Sum'
    }) -Margins -Sort

'Profit by product hierarchy and region:'
$orders |
    Pivot -Index Category, 'Sub-Category' -Columns Region -Values Profit -Aggregate Sum `
        -FillValue 0 -Margins -Outline -Grid
