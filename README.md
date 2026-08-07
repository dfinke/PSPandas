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

## Column operations

Indexing a frame by column name returns a PSPandas column object. It exposes the underlying `Values` and scalar operations such as `Sum()`, `Average()`, `Min()`, `Max()`, and `Count()`:

```powershell
$orders['OrderId'].Sum()
$orders['Amount'].Average()
$orders['Amount'].Values
```

`Count()` counts non-null values. `Sum()` ignores nulls and returns `0` for an empty or all-null column. `Average()`, `Min()`, and `Max()` ignore nulls and return `$null` when no non-null values remain. Numeric operations require numeric .NET values; incompatible non-null values throw a clear error rather than being coerced silently. Run the complete example with `& ./examples/Columns.ps1`.

## Concise summaries

`Summarize` is an alias for `Measure-PSDataFrame` with convenient array-valued operation parameters. Generated output names are deterministic: `Count_OrderId`, `Count_CustomerId`, `Sum_Amount`, and `Sum_Tax` in the order Count, Sum, Average, Min, Max, followed by any advanced `-Aggregate` entries.

```powershell
$orders = @(
    [pscustomobject]@{ State = 'East'; OrderId = 1001; CustomerId = 'C01'; Amount = 20; Tax = 2 }
    [pscustomobject]@{ State = 'East'; OrderId = 1002; CustomerId = 'C02'; Amount = 15; Tax = 1 }
    [pscustomobject]@{ State = 'West'; OrderId = 1003; CustomerId = 'C03'; Amount = 7; Tax = 1 }
) | ConvertTo-PSDataFrame

# One summary row across all orders.
$orders | Summarize -Count OrderId, CustomerId -Sum Amount, Tax |
    ConvertFrom-PSDataFrame | Format-Table

# One summary row per State.
$orders | Summarize -By State -Count OrderId, CustomerId -Sum Amount, Tax |
    ConvertFrom-PSDataFrame | Format-Table
```

The advanced `Measure-PSDataFrame -Aggregate` form remains available for custom output names and scriptblock aggregates. A friendly generated name that collides with an advanced aggregate name throws an error instead of overwriting a column. Run the complete concise-summary example with `& ./examples/Summarize.ps1`.

## Pivot tables

`ConvertTo-PSDataFrameWide` is the canonical wide-reshape command. Its concise `Pivot` and `Pivot-PSDataFrame` aliases provide a natural interactive surface while keeping module imports approved-verb and warning-free.

The repository includes an original, deterministic retail-order dataset modeled after the analytical shape of a superstore dataset. `examples/data/RetailOrders.csv` contains 144 typed line items across 72 orders, four regions, twelve states, customer segments, product categories and sub-categories, two years of dates, sales, quantity, discounts, and positive/negative profit. `examples/data/RetailOrders.xlsx` provides the same records on an `Orders` worksheet plus a `Data Dictionary` worksheet.

Run three practical geography, multi-measure, and profitability pivots with:

```powershell
& ./examples/SuperstorePivot.ps1
```

```powershell
$sales | Pivot -Index Region -Columns Channel -Values Revenue -Aggregate Sum

# Index, Columns, and Values are positional; Sum is the default aggregate.
$sales | Pivot Region Channel Revenue
```

`-Index`, `-Columns`, and `-Values` accept arrays. A string or string-array `-Aggregate` applies uniformly to every value column:

```powershell
$sales | Pivot `
    -Index Region, State `
    -Columns Year, Quarter `
    -Values Revenue, Units `
    -Aggregate Sum, Average `
    -FillValue 0
```

Use an ordered aggregate dictionary to assign different functions to each value. The dictionary order controls metric order:

```powershell
$wide = $sales | Pivot `
    -Index Region, State `
    -Columns Year, Quarter `
    -Aggregate ([ordered]@{
        Revenue = 'Sum'
        Units   = @('Sum', 'Average')
        OrderId = 'Count'
    }) `
    -FillValue 0 `
    -Margins
```

Advanced named specifications and scriptblocks use the same aggregate model as `Measure-PSDataFrame`:

```powershell
$sales | Pivot -Index Region -Columns Channel -Aggregate ([ordered]@{
    TotalRevenue = @{ Property = 'Revenue'; Function = 'Sum' }
    PeakRevenue  = @{ Property = 'Revenue'; Function = 'Max' }
    SourceRows   = { param($rows) @($rows).Count }
})
```

`Sum` is the default aggregate, making concise calls such as `Import-PSDataFrame .\orders.csv | Pivot category payment_status order_total` immediately useful. Use `-Unique` for pandas `pivot` semantics: every index/column combination must contain exactly one source row, and duplicates produce a clear error. `-Unique` cannot be combined with an explicitly supplied `-Aggregate` or with margins. Built-ins are Sum, Count, Average, Min, and Max.

PSPandas uses ordered string column names rather than hierarchical columns. A single metric produces category names such as `Online` and `Store`; multiple metrics produce deterministic names such as `Sum_Revenue_2025_Q1` and `Average_Units_2025_Q1`. Name collisions fail clearly. First-seen row and category order is preserved by default; `-Sort` sorts both axes.

`-FillValue` affects only combinations with no source rows, not existing groups whose aggregate result is null. `-Margins` recomputes each total from source rows, which keeps Average, Min, Max, and custom aggregates correct. The returned object remains a PSPandas DataFrame and retains a structured output mapping under `$wide.Metadata.Pivot` for the later long-form/melt implementation. Run the complete example with `& ./examples/Pivot.ps1`.

For a terminal-friendly hierarchical report, add `-Outline` to a pivot with two or more index dimensions:

```powershell
Import-PSDataFrame .\data\orders.csv |
    Pivot category, order_date payment_status `
        -Aggregate @{ order_status = 'Count' } `
        -FillValue 'n/a' `
        -Margins `
        -Outline `
        -Grid
```

Outline display sorts the index hierarchy, prints each primary value once, and uses tree guides (`├──`, `└──`, and `│`) to make child and sibling relationships easy to scan. Add `-Grid` to enclose headings and values in a width-calculated grid, right-align metric cells, divide primary groups, and emphasize totals. Omit `-Grid` for the lighter native table presentation. DateOnly and DateTime labels use sortable ISO-style rendering. Both presentations are display only: `$wide.Rows`, `ConvertFrom-PSDataFrame`, exports, and downstream commands retain the original typed, repeated index properties.

## Data profiling

`Import-PSDataFrame` is the file-oriented entry point. It uses PSFlatFile's typed reader for CSV, TSV, and other supported flat files. Import PSFlatFile first:

```powershell
Import-Module PSFlatFile
Import-Module ./PSPandas.psd1 -Force

$orders = Import-PSDataFrame D:\sales.csv
$orders | Describe
```

For Excel workbooks, import the optional ImportExcel module. Omit `-WorksheetName` to read the first worksheet, or provide it explicitly:

```powershell
Import-Module ImportExcel
$sales = Import-PSDataFrame D:\sales.xlsx
$sales | Describe

$sales = Import-PSDataFrame D:\sales.xlsx -WorksheetName Orders
$sales | Describe
```

`.xlsx` and `.xlsm` files use `Import-Excel`; when `-WorksheetName` is omitted, ImportExcel reads the first worksheet. Excel input does not accept the flat-file-only `Schema`, `SampleSize`, `HeaderMode`, or `NameMode` options. Workbook imports keep worksheets independent rather than merging their rows implicitly.

Use `-AsWorkbook` when the workbook contains multiple related worksheets. The result supports direct worksheet properties, tab completion, and an indexed `.Worksheets` collection:

```powershell
$book = Import-PSDataFrame D:\yearlySales.xlsx -AsWorkbook

# Press Ctrl+Space after $book. to discover worksheet names.
$book.January | Summarize -By Region -Sum Amount
$book.Worksheets['December'] | Describe
```

`$book.Worksheets.Names` preserves workbook order, and each worksheet remains an independent DataFrame. `-AsWorkbook` cannot be combined with `-WorksheetName` and is not valid for flat files.

`Get-PSDataFrameProfile` is the canonical profiling command; `Describe` is its concise alias. Both commands can also take a file path directly and use the same typed reader:

```powershell
Import-Module PSFlatFile
Import-Module ./PSPandas.psd1 -Force

Describe D:\sales.csv
Describe D:\sales.csv -AsRows |
    Where-Object Type -eq 'DateOnly' |
    Format-Table Column, Type, Minimum, Maximum
```

The constructor supports the same path workflow for compatibility:

```powershell
ConvertTo-PSDataFrame D:\sales.csv | Describe
```

Path input uses `Import-FlatFile` for type inference and does not silently fall back to `Import-Csv`. If `Import-FlatFile` is unavailable, PSPandas fails with an actionable error. The pipeline form remains available for ordinary objects:

```powershell
$data = Import-FlatFile .\orders.csv | ConvertTo-PSDataFrame
$profile = $data | Describe -SampleCount 3
$profile
```

The profile schema is `Column`, `Type`, `RowCount`, `NullCount`, `DistinctCount`, `Minimum`, `Maximum`, `Average`, `Sum`, `SampleValues`, `Earliest`, and `Latest`. Nulls are omitted from samples, distinct counts, and applicable summaries. Empty columns use `Type = 'Empty'`; all-null columns use `Type = 'Null'`; heterogeneous columns use `Type = 'Mixed'` and retain samples without throwing. `Minimum` and `Maximum` contain numeric bounds for numeric columns and typed DateTime, DateTimeOffset, or DateOnly bounds for date columns. `Average` and `Sum` are populated only for numeric columns. `Earliest` and `Latest` are retained as backward-compatible aliases for date `Minimum` and `Maximum`; they are not displayed in the default table. Samples are placed after the statistics so the most useful bounds are visible sooner in a normal console.

Use `-AsRows` when a pipeline should receive ordinary profile-row objects directly:

```powershell
$data |
    Describe -AsRows |
    Where-Object Type -eq 'DateTime' |
    Format-Table Column, Type, Minimum, Maximum
```

The direct display is uniform across source columns and includes counts, samples, typed bounds, and numeric statistics where applicable. Run the self-contained examples with `& ./examples/Profile.ps1` and `& ./examples/RichProfile.ps1`.

## Interactive DataFrame display

A DataFrame keeps its normal object and pipeline semantics, but its default PowerShell view renders the stored `Rows` as a readable table. This means a terminal pipeline can end naturally at the frame or profile:

```powershell
$orders = Import-Csv .\orders.csv | ConvertTo-PSDataFrame
$orders
$orders | Describe
```

The formatter uses the frame's current column shape, omits wrapper properties such as `Columns`, `Rows`, and `Count`, and displays an explicit empty-frame message. Profile frames render as one structured table with `Minimum`/`Maximum`; `$orders.Rows` remains available for direct row access, and `ConvertFrom-PSDataFrame` remains the explicit choice when downstream commands should receive individual rows.

Run the complete examples from the project folder with:

```powershell
& ./examples/QuickStart.ps1
& ./examples/Import.ps1
& ./examples/ExcelImport.ps1
& ./examples/Workbook.ps1
& ./examples/Grouping.ps1
& ./examples/Joins.ps1
& ./examples/Columns.ps1
& ./examples/Summarize.ps1
& ./examples/Pivot.ps1
& ./examples/SuperstorePivot.ps1
& ./examples/SalesReporting.ps1
& ./examples/Profile.ps1
& ./examples/RichProfile.ps1
```

## Supported functionality

- `Import-PSDataFrame`: read supported flat files through PSFlatFile's typed `Import-FlatFile` reader or `.xlsx`/`.xlsm` worksheets through the optional ImportExcel module. Excel imports use the first worksheet by default or the worksheet named by `-WorksheetName`. The relevant reader module must be imported or installed separately.
- `Import-PSDataFrame -AsWorkbook`: return an Excel workbook object whose ordered worksheets are independently accessible through direct tab-completable properties or `.Worksheets` indexing.
- `ConvertTo-PSDataFrame`: collect ordinary pipeline objects into a frame; explicit columns can define an empty or stable schema. A file path also delegates to the typed reader for compatibility.
- `ConvertFrom-PSDataFrame`: emit frame rows as ordinary PowerShell objects for existing commands, CSV writers, SQL clients, or later integrations.
- `Get-PSDataFrameProfile` / `Describe`: return one profile row per column with type, row/null/distinct counts, samples, numeric summaries, and typed numeric or DateTime-like bounds, including DateOnly. `-AsRows` emits ordinary profile-row objects for direct pipeline filtering.
- `Get-PSDataFrameInfo`, `Get-PSDataFrameColumn`, and `Get-PSDataFrameHead`: inspect schema, size, columns, and leading rows.
- `Find-PSDataFrame`: filter rows with a `Where-Object`-style scriptblock. `Where-PSDataFrame` remains as a compatibility alias.
- `Select-PSDataFrame`: select and reorder existing columns.
- `Set-PSDataFrameOrder`: sort by one or more columns. `Sort-PSDataFrame` remains as a compatibility alias.
- `Add-PSDataFrameColumn`: add a calculated column; the expression receives the current row through `$_` and its first argument.
- `Group-PSDataFrame`: produce stable, first-seen groups with key, rows, count, and a group frame.
- `Measure-PSDataFrame`: aggregate globally or by key. Aggregate specifications may be scriptblocks, property names (sum by default), or `@{ Property = 'Amount'; Function = 'Sum' }` hashtables. For non-count hashtable specifications that omit `Property`, the aggregate output name is used as the source property name. Built-ins include Count, Sum, Average, Min, and Max. `Summarize` is a concise alias for the friendly parameter surface, and `Summarize-PSDataFrame` remains as a compatibility alias.
- `ConvertTo-PSDataFrameWide` / `Pivot`: reshape one or more column dimensions into ordered output columns. Supports multiple index dimensions, multiple values, uniform or per-value aggregates, advanced named/scriptblock aggregates, fill values, sorting, margins, uniqueness validation, structured pivot metadata, an optional hierarchical `-Outline` report view, and opt-in `-Grid` borders.
- `Join-PSDataFrame`: inner, left, right, and full joins on one or more keys. Non-key collisions receive `_left` and `_right` suffixes by default.

All transformations preserve input row order where ordering is meaningful. Empty frames retain an explicitly supplied schema; empty transformations return empty frames with their expected columns.

## First-release limitations and roadmap

The first milestone includes wide pivot tables but leaves long-form melt/reshape, a formal missing-value policy, automatic type coercion, and performance optimization for very large datasets as follow-on work. PSDolt-specific integration is also intentionally deferred: ordinary pipeline objects emitted by PSDolt can already be collected with `ConvertTo-PSDataFrame` when that integration is added later.

## Development

Run the test suite from the project folder:

```powershell
Invoke-Pester ./tests -Output Detailed
```

The runnable examples are `examples/QuickStart.ps1`, `examples/Import.ps1`, `examples/ExcelImport.ps1`, `examples/Workbook.ps1`, `examples/Grouping.ps1`, `examples/Joins.ps1`, `examples/Columns.ps1`, `examples/Summarize.ps1`, `examples/Pivot.ps1`, `examples/SuperstorePivot.ps1`, `examples/SalesReporting.ps1`, `examples/Profile.ps1`, and `examples/RichProfile.ps1`.
