<#
.SYNOPSIS
Demonstrates indexed DataFrame column operations.

.DESCRIPTION
Builds a frame and uses the column object Values, Sum, Average, Min, Max, and
Count members without unwrapping the DataFrame.

.EXAMPLE
& ./examples/Columns.ps1
#>

Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$orders = @(
    [pscustomobject][ordered]@{ OrderId = 1001; Amount = 20 }
    [pscustomobject][ordered]@{ OrderId = 1002; Amount = 15 }
    [pscustomobject][ordered]@{ OrderId = 1003; Amount = 7 }
) | ConvertTo-PSDataFrame

'OrderId sum: {0}' -f $orders['OrderId'].Sum()
'Average amount: {0}' -f $orders['Amount'].Average()
'OrderId values: {0}' -f (($orders['OrderId'].Values) -join ', ')
