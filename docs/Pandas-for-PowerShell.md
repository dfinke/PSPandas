# Pandas Thinking in PowerShell

This tutorial introduces PSPandas through one practical workflow: load retail
orders, inspect the data, transform it, summarize it, reshape it, and pass the
results to ordinary PowerShell commands.(Written in the style of Walt Whitman's "To a Locomotive in Winter")

PSPandas is inspired by the useful parts of Python pandas, but the idioms are
PowerShell-native. DataFrames remain objects in the pipeline, rows remain
ordinary PowerShell objects, and formatting is normally the last step.

The complete runnable companion is [`examples/PandasForPowerShell.ps1`](../examples/PandasForPowerShell.ps1):

```powershell
& ./examples/PandasForPowerShell.ps1
```

## The pandas-to-PowerShell map

| Python pandas | PSPandas |
| --- | --- |
| `pd.DataFrame(data)` | `ConvertTo-PSDataFrame` |
| `pd.read_csv(path)` | `Import-PSDataFrame path` |
| `df.head()` | `Get-PSDataFrameHead` |
| `df.info()` | `Get-PSDataFrameInfo` |
| `df.describe()` | `Describe` |
| `df["Amount"].sum()` | `$df['Amount'].Sum()` |
| `df[df["Amount"] > 100]` | `Find-PSDataFrame { $_.Amount -gt 100 }` |
| `df[["A", "B"]]` | `Select-PSDataFrame A, B` |
| `df.assign(...)` | `Add-PSDataFrameColumn` |
| `df.groupby(...).agg(...)` | `Summarize -By ...` |
| `df.pivot_table(...)` | `Pivot` |
| `pd.crosstab(...)` | `Crosstab` |
| `pd.merge(...)` | `Join-PSDataFrame` |
| `pd.concat(...)` | `Concat` |
| `pd.date_range(...)` | `Get-PSDateRange` |

The canonical commands use approved PowerShell verbs. The concise commands
`Describe`, `Summarize`, `Pivot`, `Crosstab`, and `Concat` are intentional
convenience aliases.

## 1. Import and inspect

Import the module and read the included typed CSV. PSPandas infers practical
types such as integers, decimals, booleans, DateOnly values, and strings.

```powershell
Import-Module ./PSPandas.psd1 -Force

$orders = Import-PSDataFrame ./examples/data/RetailOrders.csv
$orders

$orders | Get-PSDataFrameInfo
$orders | Get-PSDataFrameHead -Count 5
$orders | Get-PSDataFrameColumn
```

`$orders` is still a PSPandas DataFrame after every transformation. Use
`ConvertFrom-PSDataFrame` when a command specifically needs ordinary rows.

## 2. Filter and select

Use a PowerShell scriptblock for row filtering. The current row is available as
`$_`, just as it is with `Where-Object`.

```powershell
$profitable = $orders |
    Find-PSDataFrame { $_.Profit -gt 500 } |
    Select-PSDataFrame -Property 'Order ID', Region, Sales, Profit

$profitable | ConvertFrom-PSDataFrame | Format-Table
```

`Find-PSDataFrame` preserves the original row and column order. Its older
`Where-PSDataFrame` alias remains available for compatibility.

## 3. Add calculated columns

Calculated columns receive the current row through `$_`. This is useful when a
later summary needs a derived dimension.

```powershell
$orders = $orders |
    Add-PSDataFrameColumn -Name Year -Expression { $_.'Order Date'.Year }

$orders | Get-PSDataFrameHead -Count 3
```

This is the PowerShell equivalent of creating a column from an expression, but
the expression is an ordinary PowerShell scriptblock.

## 4. Work with a column directly

Indexing by column name returns a PSPandas column object rather than a raw
array. It supports scalar operations and indexed values:

```powershell
$orders['Sales'].Sum()
$orders['Sales'].Average()
$orders['Sales'][0..2]
$orders['Sales'].Values
```

`Count()` ignores nulls. `Sum()` ignores nulls and returns zero for an empty or
all-null column. `Average()`, `Min()`, and `Max()` return `$null` when no
non-null values remain. Numeric operations reject incompatible values clearly.

## 5. Summarize globally or by group

The friendly `Summarize` surface accepts arrays of property names:

```powershell
# One row across all orders.
$orders |
    Summarize -Count 'Order ID' -Sum Sales, Profit |
    ConvertFrom-PSDataFrame | Format-Table

# One row per region.
$byRegion = $orders |
    Summarize -By Region -Count 'Order ID' -Sum Sales, Profit

$byRegion | ConvertFrom-PSDataFrame | Format-Table
```

Output names are deterministic: `Count_Order ID`, `Sum_Sales`, and
`Sum_Profit`. For custom names or scriptblock aggregations, use the advanced
form:

```powershell
$orders | Measure-PSDataFrame -By Region -Aggregate ([ordered]@{
    Orders  = @{ Function = 'Count' }
    Revenue = @{ Property = 'Sales'; Function = 'Sum' }
})
```

## 6. Pivot measures into columns

`Pivot` is the concise surface for wide reshaping. The result keeps index
columns and creates one output column for each category/measure combination.

```powershell
$orders |
    Pivot -Index Region -Columns Category -Values Sales -Aggregate Sum -FillValue 0
```

Multiple dimensions and measures are supported:

```powershell
$orders |
    Pivot -Index Region, State -Columns Year, 'Ship Mode' `
        -Values Sales, Profit -Aggregate Sum -FillValue 0
```

When `Values` is omitted, `Pivot Index Columns` becomes a frequency pivot with
integer counts, equivalent to a crosstab. Use `-Outline` or `-Grid` when you
want a report-style display; the underlying rows remain structured.

## 7. Count combinations with Crosstab

`Crosstab` counts combinations of dimensions and fills absent combinations with
zero by default:

```powershell
$orders |
    Crosstab -Index Region -Columns Segment -FillValue 0
```

Normalize when proportions are more useful than counts:

```powershell
$orders |
    Crosstab -Index Region -Columns Segment -Normalize Index -Percent
```

The result contains numeric percentage-point values, so they remain useful in
PowerShell calculations and exports. `-Margins` is intentionally disallowed
with normalized crosstabs because mixed total semantics are ambiguous.

## 8. Join related frames

`Join-PSDataFrame` performs keyed inner, left, right, and full joins. The right
frame can be built from ordinary PowerShell objects:

```powershell
$customers = @(
    [pscustomobject]@{ CustomerId = 'C01'; Customer = 'Ada' }
    [pscustomobject]@{ CustomerId = 'C02'; Customer = 'Bea' }
) | ConvertTo-PSDataFrame

$ordersForJoin = @(
    [pscustomobject]@{ OrderId = 1001; CustomerId = 'C01'; Amount = 20 }
    [pscustomobject]@{ OrderId = 1002; CustomerId = 'C99'; Amount = 7 }
) | ConvertTo-PSDataFrame

Join-PSDataFrame -Left $ordersForJoin -Right $customers `
    -On CustomerId -JoinType Left |
    ConvertFrom-PSDataFrame | Format-Table
```

The unmatched `C99` order is retained by the left join and its right-side
customer value is `$null`.

## 9. Concatenate frames

Use `Concat` when rows should be appended rather than matched by a key:

```powershell
$first = $orders | Get-PSDataFrameHead -Count 5 | ConvertTo-PSDataFrame
$last  = $orders | Get-PSDataFrameTail -Count 5 | ConvertTo-PSDataFrame

$combined = $first, $last | Concat
$combined | Get-PSDataFrameInfo
```

Columns are unioned in first-seen order and missing values become `$null`.

## 10. Create a calendar range

`Get-PSDateRange` is the PSPandas equivalent of `pandas.date_range`:

```powershell
$monthStarts = Get-PSDateRange `
    -Start '2025-01-01' -Periods 12 -Frequency MonthStart -DateOnly

$monthStarts | ForEach-Object {
    [pscustomobject]@{ MonthStart = $_ }
}
```

Supported frequencies include `Day`, `Hour`, `Week`, `BusinessDay`,
`MonthStart`, `MonthEnd`, `QuarterStart`, and `YearStart`, plus short names
such as `D`, `B`, `MS`, and `YS`.

## 11. Profile and check the data

`Describe` returns a profile DataFrame with one row per source column:

```powershell
$orders | Describe
```

Profile rows include type, row count, null count, distinct count, samples, and
applicable numeric or date bounds. DateOnly and DateTime bounds retain their
typed values in the underlying rows and display in ISO form.

Use `-AsRows` when the next command should receive ordinary PowerShell objects:

```powershell
$orders |
    Describe -AsRows |
    Where-Object Type -eq 'Numeric' |
    Select-Object Column, Minimum, Maximum, Average, Sum
```

The default result is still a PSPandas DataFrame, so it can be inspected with
`.Rows`, passed to DataFrame commands, or exported after conversion.

## The complete workflow

Run the companion script to see all of these operations together:

```powershell
& ./examples/PandasForPowerShell.ps1
```

For command-level details, use PowerShell help:

```powershell
Get-Help Import-PSDataFrame -Full
Get-Help Summarize -Full
Get-Help Pivot -Full
Get-Help Crosstab -Full
Get-Help Describe -Full
```
