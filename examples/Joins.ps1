Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

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
