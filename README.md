# PSPandas

PSPandas is a PowerShell-native data-manipulation module inspired by the practical parts of pandas. It keeps data as ordered columns plus rows represented by ordinary PowerShell objects, so it fits naturally between commands in a pipeline.

The first release is intentionally a focused foundation. It is not a literal pandas port and does not require Python.

## Installation and import

Clone or copy this folder into a module path, or import it directly while developing:

```powershell
Import-Module ./PSPandas.psd1 -Force
```

For a user-scoped installation, copy the project folder beneath one of the paths returned by `$env:PSModulePath`, then run:

```powershell
Import-Module PSPandas
```

## Quick start

```powershell
Import-Module ./PSPandas.psd1 -Force

$sales = @(
    [pscustomobject]@{ Region = 'East'; Product = 'A'; Quantity = 2; Amount = 20 }
    [pscustomobject]@{ Region = 'West'; Product = 'B'; Quantity = 1; Amount = 15 }
    [pscustomobject]@{ Region = 'East'; Product = 'C'; Quantity = 3; Amount = 45 }
) | ConvertTo-PSDataFrame

$sales | Get-PSDataFrameInfo
$sales | Find-PSDataFrame { $_.Amount -gt 20 } |
    Add-PSDataFrameColumn -Name UnitPrice -Expression { $_.Amount / $_.Quantity } |
    Select-PSDataFrame Region, Product, UnitPrice |
    ConvertFrom-PSDataFrame | Format-Table

$summary = $sales | Measure-PSDataFrame -By Region -Aggregate ([ordered]@{
    Orders = @{ Function = 'Count' }
    Revenue = @{ Property = 'Amount'; Function = 'Sum' }
})
$summary | ConvertFrom-PSDataFrame | Format-Table
```

## Grouping and joins

`Group-PSDataFrame` returns group objects rather than a new summary frame. Each group has `Key`, `Rows`, `Count`, and `DataFrame` properties. Use those objects directly or follow grouping with `Measure-PSDataFrame`:

```powershell
$sales = @(
    [pscustomobject][ordered]@{ Region = 'East'; Product = 'A'; Quantity = 2; Amount = 20 }
    [pscustomobject][ordered]@{ Region = 'West'; Product = 'B'; Quantity = 1; Amount = 15 }
    [pscustomobject][ordered]@{ Region = 'East'; Product = 'C'; Quantity = 3; Amount = 45 }
) | ConvertTo-PSDataFrame

$groups = $sales | Group-PSDataFrame -By Region
$groups | ForEach-Object {
    [pscustomobject]@{
        Region   = $_.Key
        Rows     = $_.Count
        Products = (@($_.Rows | ForEach-Object Product) -join ', ')
    }
} | Format-Table

$sales | Measure-PSDataFrame -By Region -Aggregate ([ordered]@{
    Orders  = @{ Function = 'Count' }
    Revenue = @{ Property = 'Amount'; Function = 'Sum' }
}) | ConvertFrom-PSDataFrame | Format-Table
```

`Join-PSDataFrame` takes two frames and an explicit key. This left join keeps the unmatched order and emits the left columns followed by the right-side non-key column:

```powershell
$orders = @(
    [pscustomobject]@{ OrderId = 1001; CustomerId = 'C01'; Amount = 20 }
    [pscustomobject]@{ OrderId = 1002; CustomerId = 'C02'; Amount = 15 }
    [pscustomobject]@{ OrderId = 1003; CustomerId = 'C99'; Amount = 7 }
) | ConvertTo-PSDataFrame

$customers = @(
    [pscustomobject]@{ CustomerId = 'C01'; Customer = 'Ada' }
    [pscustomobject]@{ CustomerId = 'C02'; Customer = 'Bea' }
) | ConvertTo-PSDataFrame

Join-PSDataFrame -Left $orders -Right $customers -On CustomerId -JoinType Left |
    ConvertFrom-PSDataFrame | Format-Table
# Columns: OrderId, CustomerId, Amount, Customer
```

Run both complete examples from the project folder with:

```powershell
& ./examples/QuickStart.ps1
& ./examples/GroupingAndJoins.ps1
```

## Supported functionality

- `ConvertTo-PSDataFrame`: collect ordinary pipeline objects into a frame; explicit columns can define an empty or stable schema.
- `ConvertFrom-PSDataFrame`: emit frame rows as ordinary PowerShell objects for existing commands, CSV writers, SQL clients, or later integrations.
- `Get-PSDataFrameInfo`, `Get-PSDataFrameColumn`, and `Get-PSDataFrameHead`: inspect schema, size, columns, and leading rows.
- `Find-PSDataFrame`: filter rows with a `Where-Object`-style scriptblock. `Where-PSDataFrame` remains as a compatibility alias.
- `Select-PSDataFrame`: select and reorder existing columns.
- `Set-PSDataFrameOrder`: sort by one or more columns. `Sort-PSDataFrame` remains as a compatibility alias.
- `Add-PSDataFrameColumn`: add a calculated column; the expression receives the current row through `$_` and its first argument.
- `Group-PSDataFrame`: produce stable, first-seen groups with key, rows, count, and a group frame.
- `Measure-PSDataFrame`: aggregate globally or by key. Aggregate specifications may be scriptblocks, property names (sum by default), or `@{ Property = 'Amount'; Function = 'Sum' }` hashtables. For non-count hashtable specifications that omit `Property`, the aggregate output name is used as the source property name. Built-ins include Count, Sum, Average, Min, and Max. `Summarize-PSDataFrame` remains as a compatibility alias.
- `Join-PSDataFrame`: inner, left, right, and full joins on one or more keys. Non-key collisions receive `_left` and `_right` suffixes by default.

All transformations preserve input row order where ordering is meaningful. Empty frames retain an explicitly supplied schema; empty transformations return empty frames with their expected columns.

## First-release limitations and roadmap

The first milestone deliberately leaves out pivot/reshape operations, a formal missing-value policy, automatic type coercion, and performance optimization for very large datasets. Those are follow-on work after the core object model and transformation semantics have more usage behind them. PSDolt-specific integration is also intentionally deferred: ordinary pipeline objects emitted by PSDolt can already be collected with `ConvertTo-PSDataFrame` when that integration is added later.

## Development

Run the test suite from the project folder:

```powershell
Invoke-Pester ./tests -Output Detailed
```

The runnable examples are `examples/QuickStart.ps1` and `examples/GroupingAndJoins.ps1`.
