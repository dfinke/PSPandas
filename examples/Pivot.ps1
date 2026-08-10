<#
.SYNOPSIS
Demonstrates PSPandas wide pivot capabilities.

.DESCRIPTION
Shows positional pivot syntax, multiple dimensions and metrics, per-value
aggregates, margins, outline display, and structured pivot metadata.

.EXAMPLE
& ./examples/Pivot.ps1
#>

Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$sales = @(
    [pscustomobject][ordered]@{ Region = 'East'; State = 'NY'; Year = 2025; Quarter = 'Q1'; Channel = 'Online'; Revenue = 1250; Units = 10; OrderId = 'ORD-1001' }
    [pscustomobject][ordered]@{ Region = 'East'; State = 'NY'; Year = 2025; Quarter = 'Q1'; Channel = 'Online'; Revenue = 750;  Units = 6;  OrderId = 'ORD-1002' }
    [pscustomobject][ordered]@{ Region = 'East'; State = 'NY'; Year = 2025; Quarter = 'Q2'; Channel = 'Store';  Revenue = 1800; Units = 12; OrderId = 'ORD-1003' }
    [pscustomobject][ordered]@{ Region = 'South'; State = 'TX'; Year = 2025; Quarter = 'Q1'; Channel = 'Store';  Revenue = 2100; Units = 14; OrderId = 'ORD-1004' }
    [pscustomobject][ordered]@{ Region = 'South'; State = 'TX'; Year = 2025; Quarter = 'Q2'; Channel = 'Online'; Revenue = 900;  Units = 7;  OrderId = 'ORD-1005' }
) | ConvertTo-PSDataFrame

'Revenue by region and channel:'
$sales |
    Pivot Region Channel Revenue -FillValue 0

'Multiple dimensions, values, and per-value aggregates:'
$wide = $sales |
    Pivot -Index Region, State -Columns Year, Quarter -Aggregate ([ordered]@{
        Revenue = 'Sum'
        Units   = @('Sum', 'Average')
        OrderId = 'Count'
    }) -FillValue 0 -Margins -Outline -Grid
$wide

'Structured mapping retained for later reshape operations:'
$wide.Metadata.Pivot.ColumnMap.Values |
    Select-Object -First 3 MetricName, Property, Function, ColumnValues, IsMargin |
    Format-Table

$events = @(
    [pscustomobject]@{ User = 'Alice'; Action = 'Login' }
    [pscustomobject]@{ User = 'Alice'; Action = 'Login' }
    [pscustomobject]@{ User = 'Alice'; Action = 'Logout' }
    [pscustomobject]@{ User = 'Bob'; Action = 'Login' }
    [pscustomobject]@{ User = 'Charlie'; Action = 'Logout' }
) | ConvertTo-PSDataFrame

'Frequency pivot when Values are omitted:'
$events | Pivot User Action
