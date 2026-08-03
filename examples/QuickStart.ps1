Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$sales = @(
    [pscustomobject]@{ Region = 'East'; Product = 'A'; Quantity = 2; Amount = 20 }
    [pscustomobject]@{ Region = 'West'; Product = 'B'; Quantity = 1; Amount = 15 }
    [pscustomobject]@{ Region = 'East'; Product = 'C'; Quantity = 3; Amount = 45 }
) | ConvertTo-PSDataFrame

'Frame information:'
$sales | Get-PSDataFrameInfo | Format-List

'Filtered and calculated rows:'
$sales |
    Find-PSDataFrame { $_.Amount -ge 20 } |
    Add-PSDataFrameColumn -Name UnitPrice -Expression { $_.Amount / $_.Quantity } |
    ConvertFrom-PSDataFrame |
    Format-Table

'Summary by region:'
$sales |
    Measure-PSDataFrame -By Region -Aggregate ([ordered]@{
        Orders  = @{ Function = 'Count' }
        Revenue = @{ Property = 'Amount'; Function = 'Sum' }
    }) |
    ConvertFrom-PSDataFrame |
    Format-Table
