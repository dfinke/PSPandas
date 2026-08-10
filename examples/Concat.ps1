<#
.SYNOPSIS
Concatenates two DataFrames with different but related columns.

.DESCRIPTION
Demonstrates vertical concatenation, first-seen column ordering, null filling
for missing columns, and the pipeline-friendly Concat alias.

.EXAMPLE
& ./examples/Concat.ps1
#>

Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$firstHalf = @(
    [pscustomobject][ordered]@{ OrderId = 'ORD-2001'; Region = 'West';  Amount = 125.50 }
    [pscustomobject][ordered]@{ OrderId = 'ORD-2002'; Region = 'East';  Amount = 88.00 }
) | ConvertTo-PSDataFrame

$secondHalf = @(
    [pscustomobject][ordered]@{ OrderId = 'ORD-2003'; Region = 'South'; Amount = 214.25; Channel = 'Online' }
    [pscustomobject][ordered]@{ OrderId = 'ORD-2004'; Region = 'North'; Amount = 64.75;  Channel = 'Store' }
) | ConvertTo-PSDataFrame

$combined = $firstHalf, $secondHalf | Concat
$combined
