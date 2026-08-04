Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$orders = @(
    [pscustomobject][ordered]@{ State = 'East'; OrderId = 1001; CustomerId = 'C01'; Amount = 20; Tax = 2 }
    [pscustomobject][ordered]@{ State = 'East'; OrderId = 1002; CustomerId = 'C02'; Amount = 15; Tax = 1 }
    [pscustomobject][ordered]@{ State = 'West'; OrderId = 1003; CustomerId = 'C03'; Amount = 7; Tax = 1 }
) | ConvertTo-PSDataFrame

'Ungrouped summary:'
$orders |
    Summarize -Count OrderId, CustomerId -Sum Amount, Tax |
    ConvertFrom-PSDataFrame |
    Format-Table

'Grouped summary:'
$orders |
    Summarize -By State -Count OrderId, CustomerId -Sum Amount, Tax |
    ConvertFrom-PSDataFrame |
    Format-Table
