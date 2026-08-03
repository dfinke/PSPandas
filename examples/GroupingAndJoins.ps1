Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$sales = @(
    [pscustomobject][ordered]@{ Region = 'East'; Product = 'A'; Quantity = 2; Amount = 20 }
    [pscustomobject][ordered]@{ Region = 'West'; Product = 'B'; Quantity = 1; Amount = 15 }
    [pscustomobject][ordered]@{ Region = 'East'; Product = 'C'; Quantity = 3; Amount = 45 }
) | ConvertTo-PSDataFrame

'Groups:'
$groups = $sales | Group-PSDataFrame -By Region
$groups | ForEach-Object {
    [pscustomobject][ordered]@{
        Region = $_.Key
        Rows   = $_.Count
        Products = (@($_.Rows | ForEach-Object Product) -join ', ')
    }
} | Format-Table

'Summary built from the same frame:'
$sales |
    Measure-PSDataFrame -By Region -Aggregate ([ordered]@{
        Orders  = @{ Function = 'Count' }
        Revenue = @{ Property = 'Amount'; Function = 'Sum' }
    }) |
    ConvertFrom-PSDataFrame |
    Format-Table

$orders = @(
    [pscustomobject][ordered]@{ OrderId = 1001; CustomerId = 'C01'; Amount = 20 }
    [pscustomobject][ordered]@{ OrderId = 1002; CustomerId = 'C02'; Amount = 15 }
    [pscustomobject][ordered]@{ OrderId = 1003; CustomerId = 'C99'; Amount = 7 }
) | ConvertTo-PSDataFrame

$customers = @(
    [pscustomobject][ordered]@{ CustomerId = 'C01'; Customer = 'Ada' }
    [pscustomobject][ordered]@{ CustomerId = 'C02'; Customer = 'Bea' }
) | ConvertTo-PSDataFrame

'Left join on CustomerId (the unmatched C99 row is retained):'
Join-PSDataFrame -Left $orders -Right $customers -On CustomerId -JoinType Left |
    ConvertFrom-PSDataFrame |
    Format-Table
