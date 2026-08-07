function ConvertTo-PSDataFrameWide {
    <#
    .SYNOPSIS
    Reshapes a PSPandas DataFrame into a wide pivot table.

    .DESCRIPTION
    Creates one output row for each unique -Index combination and one or more
    output columns for each unique -Columns combination. With -Aggregate,
    duplicate cells are combined using Sum, Count, Average, Min, or Max. Sum is
    the default so `Pivot Region Channel Amount` is immediately useful. Use
    -Unique when every index/column combination must contain exactly one row.

    A string or string-array -Aggregate applies uniformly to every -Values
    column. An ordered dictionary can assign different functions to each value
    column or provide advanced named Property/Function specifications. Multiple
    dimensions are flattened into deterministic string column names while
    structured mappings are retained in the result's Metadata.Pivot property.

    .PARAMETER DataFrame
    PSPandas DataFrame to reshape. The command accepts pipeline input.

    .PARAMETER Index
    Zero or more columns that identify output rows. Multiple columns form a
    composite row key in the order supplied.

    .PARAMETER Columns
    One or more columns whose distinct value combinations become output columns.

    .PARAMETER Values
    Value columns used by a uniqueness-enforcing pivot or by uniform aggregate
    functions. Omit this parameter when -Aggregate is a dictionary.

    .PARAMETER Aggregate
    A function name, an array of function names, or an ordered dictionary. A
    dictionary can map value columns to functions, for example
    [ordered]@{ Revenue = 'Sum'; Units = @('Sum', 'Average') }, or use advanced
    named specifications such as
    [ordered]@{ TotalRevenue = @{ Property='Revenue'; Function='Sum' } }.
    Defaults to Sum.

    .PARAMETER Unique
    Disables aggregation and requires every index/column combination to be
    unique. Cannot be combined with an explicitly supplied -Aggregate or with
    -Margins.

    .PARAMETER FillValue
    Value placed only in output cells for which no source rows exist. Null
    aggregate results from existing source rows are not replaced.

    .PARAMETER Margins
    Adds total columns and, when -Index is present, a grand-total row. Every
    margin is recomputed from its source rows rather than from displayed cells.

    .PARAMETER MarginsName
    Label used for margin columns and the grand-total row. Defaults to Total.

    .PARAMETER Sort
    Sorts index combinations and pivoted column combinations by their rendered
    labels. Without this switch, first-seen source order is preserved.

    .PARAMETER Outline
    Uses the pivot index metadata to render a terminal-friendly hierarchical
    report. The primary index is printed once and each additional level uses
    tree guides such as ├──, └──, and │ to show sibling and parent
    relationships. Outline implies -Sort but does not change the DataFrame's
    typed rows or pipeline behavior.

    .PARAMETER Grid
    Encloses an outline report in a width-calculated grid, right-aligns metric
    values, separates primary groups, and emphasizes margins. Requires -Outline.

    .PARAMETER NameSeparator
    Separator used when flattening multiple dimensions and metric names into
    output column names. Defaults to an underscore.

    .PARAMETER NullColumnName
    Label used when a pivot column dimension contains null or DBNull. Defaults
    to [null].

    .EXAMPLE
    $sales | Pivot -Index Region -Columns Quarter -Values Revenue -Aggregate Sum

    .EXAMPLE
    $sales | Pivot Region Quarter Revenue

    .EXAMPLE
    $sales | Pivot Region, OrderDate PaymentStatus OrderTotal -Margins -Outline -Grid

    .EXAMPLE
    $sales | ConvertTo-PSDataFrameWide -Index Region, State -Columns Year, Quarter -Aggregate ([ordered]@{
        Revenue = 'Sum'
        Units   = @('Sum', 'Average')
        OrderId = 'Count'
    }) -FillValue 0 -Margins

    .OUTPUTS
    PSPandas.DataFrame
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true)]$DataFrame,
        [Parameter(Position = 0)][AllowEmptyCollection()][string[]]$Index = @(),
        [Parameter(Mandatory, Position = 1)][Alias('Column')][ValidateCount(1, 2147483647)][string[]]$Columns,
        [Parameter(Position = 2)][AllowEmptyCollection()][Alias('Value')][string[]]$Values = @(),
        [AllowNull()][object]$Aggregate = 'Sum',
        [switch]$Unique,
        [AllowNull()][object]$FillValue,
        [switch]$Margins,
        [ValidateNotNullOrEmpty()][string]$MarginsName = 'Total',
        [switch]$Sort,
        [switch]$Outline,
        [switch]$Grid,
        [ValidateNotNullOrEmpty()][string]$NameSeparator = '_',
        [ValidateNotNullOrEmpty()][string]$NullColumnName = '[null]'
    )

    process {
        Assert-PSPandasDataFrame -DataFrame $DataFrame

        $dimensionNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($name in @($Index) + @($Columns)) {
            if ([string]::IsNullOrWhiteSpace($name)) {
                throw 'Pivot index and column dimension names cannot be empty.'
            }
            if (-not $dimensionNames.Add($name)) {
                throw "Pivot dimension '$name' is duplicated or used in both -Index and -Columns."
            }
        }
        Assert-PSPandasColumns -DataFrame $DataFrame -Columns (@($Index) + @($Columns))
        if ($Outline -and $Index.Count -lt 2) {
            throw '-Outline requires at least two -Index columns so child levels can be indented beneath a primary level.'
        }
        if ($Grid -and -not $Outline) {
            throw '-Grid requires -Outline because the grid is an outline report presentation option.'
        }
        if ($Outline) {
            $Sort = $true
        }

        if ($Unique -and $PSBoundParameters.ContainsKey('Aggregate')) {
            throw '-Unique cannot be combined with an explicitly supplied -Aggregate.'
        }
        $aggregateWasSpecified = -not $Unique
        $metrics = @(Resolve-PSPandasPivotMetrics -DataFrame $DataFrame -Values $Values -Aggregate $Aggregate -AggregateWasSpecified:$aggregateWasSpecified)
        if ($Margins -and -not $aggregateWasSpecified) {
            throw '-Margins requires -Aggregate because totals cannot be inferred for a uniqueness-enforcing pivot.'
        }

        $indexGroups = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
        $indexOrder = [System.Collections.Generic.List[string]]::new()
        $categoryInfo = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
        $categoryOrder = [System.Collections.Generic.List[string]]::new()
        $allRows = [System.Collections.Generic.List[object]]::new()

        foreach ($row in @($DataFrame.Rows)) {
            [void]$allRows.Add($row)
            $indexValues = [object[]]@($Index | ForEach-Object { Get-PSPandasPropertyValue -InputObject $row -Name $_ })
            $categoryValues = [object[]]@($Columns | ForEach-Object { Get-PSPandasPropertyValue -InputObject $row -Name $_ })
            $indexKey = ConvertTo-PSPandasStableKey -Values $indexValues
            $categoryKey = ConvertTo-PSPandasStableKey -Values $categoryValues

            if (-not $indexGroups.ContainsKey($indexKey)) {
                $indexGroups[$indexKey] = [pscustomobject]@{
                    IndexValues = $indexValues
                    Rows        = [System.Collections.Generic.List[object]]::new()
                    Cells       = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
                }
                [void]$indexOrder.Add($indexKey)
            }
            $group = $indexGroups[$indexKey]
            [void]$group.Rows.Add($row)
            if (-not $group.Cells.ContainsKey($categoryKey)) {
                $group.Cells[$categoryKey] = [System.Collections.Generic.List[object]]::new()
            }
            [void]$group.Cells[$categoryKey].Add($row)

            if (-not $categoryInfo.ContainsKey($categoryKey)) {
                $categoryInfo[$categoryKey] = [pscustomobject]@{
                    Values = $categoryValues
                    Label  = $null
                    Rows   = [System.Collections.Generic.List[object]]::new()
                }
                [void]$categoryOrder.Add($categoryKey)
            }
            [void]$categoryInfo[$categoryKey].Rows.Add($row)
        }

        $categoryLabels = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($categoryKey in $categoryOrder) {
            $category = $categoryInfo[$categoryKey]
            $category.Label = ConvertTo-PSPandasPivotTupleLabel -Values $category.Values -Separator $NameSeparator -NullColumnName $NullColumnName
            if ($categoryLabels.ContainsKey($category.Label) -and $categoryLabels[$category.Label] -ne $categoryKey) {
                throw "Distinct pivot column combinations render as the same label '$($category.Label)'. Choose a different -NameSeparator or normalize the source values."
            }
            $categoryLabels[$category.Label] = $categoryKey
        }

        if ($Sort) {
            $categoryOrder = [System.Collections.Generic.List[string]]@($categoryOrder | Sort-Object { $categoryInfo[$_].Label })
            $indexOrder = [System.Collections.Generic.List[string]]@($indexOrder | Sort-Object {
                ConvertTo-PSPandasPivotTupleLabel -Values $indexGroups[$_].IndexValues -Separator $NameSeparator -NullColumnName $NullColumnName
            })
        }

        $outputColumns = [System.Collections.Generic.List[string]]::new()
        $usedColumnNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($name in $Index) {
            [void]$outputColumns.Add($name)
            [void]$usedColumnNames.Add($name)
        }

        $columnMap = [ordered]@{}
        $metricHasPrefix = $metrics.Count -gt 1
        foreach ($metric in $metrics) {
            foreach ($categoryKey in $categoryOrder) {
                $category = $categoryInfo[$categoryKey]
                $outputName = if ($metricHasPrefix) {
                    "{0}{1}{2}" -f $metric.Name, $NameSeparator, $category.Label
                } else {
                    $category.Label
                }
                if ([string]::IsNullOrWhiteSpace($outputName) -or -not $usedColumnNames.Add($outputName)) {
                    throw "Pivot generated a duplicate or empty output column name '$outputName'. Change the dimensions, aggregate names, or -NameSeparator."
                }
                [void]$outputColumns.Add($outputName)
                $columnMap[$outputName] = [pscustomobject][ordered]@{
                    MetricName   = $metric.Name
                    Property     = $metric.Property
                    Function     = $metric.Function
                    ColumnValues = [object[]]$category.Values
                    IsMargin     = $false
                }
            }
            if ($Margins) {
                $outputName = if ($metricHasPrefix) {
                    "{0}{1}{2}" -f $metric.Name, $NameSeparator, $MarginsName
                } else {
                    $MarginsName
                }
                if (-not $usedColumnNames.Add($outputName)) {
                    throw "Margins name '$MarginsName' collides with a generated pivot column. Choose a different -MarginsName."
                }
                [void]$outputColumns.Add($outputName)
                $columnMap[$outputName] = [pscustomobject][ordered]@{
                    MetricName   = $metric.Name
                    Property     = $metric.Property
                    Function     = $metric.Function
                    ColumnValues = $null
                    IsMargin     = $true
                }
            }
        }

        if ($Margins -and $Index.Count -gt 0) {
            $marginIndexValues = [object[]]::new($Index.Count)
            $marginIndexValues[0] = $MarginsName
            $marginIndexKey = ConvertTo-PSPandasStableKey -Values $marginIndexValues
            if ($indexGroups.ContainsKey($marginIndexKey)) {
                throw "Margins name '$MarginsName' collides with an existing index combination. Choose a different -MarginsName."
            }
        }

        $resultRows = [System.Collections.Generic.List[object]]::new()
        foreach ($indexKey in $indexOrder) {
            $group = $indexGroups[$indexKey]
            $ordered = [ordered]@{}
            for ($indexPosition = 0; $indexPosition -lt $Index.Count; $indexPosition++) {
                $ordered[$Index[$indexPosition]] = $group.IndexValues[$indexPosition]
            }

            foreach ($metric in $metrics) {
                foreach ($categoryKey in $categoryOrder) {
                    $category = $categoryInfo[$categoryKey]
                    $outputName = if ($metricHasPrefix) { "{0}{1}{2}" -f $metric.Name, $NameSeparator, $category.Label } else { $category.Label }
                    if ($group.Cells.ContainsKey($categoryKey)) {
                        $ordered[$outputName] = Get-PSPandasPivotCellValue -Rows ([object[]]$group.Cells[$categoryKey].ToArray()) -Metric $metric
                    } else {
                        $ordered[$outputName] = if ($PSBoundParameters.ContainsKey('FillValue')) { $FillValue } else { $null }
                    }
                }
                if ($Margins) {
                    $outputName = if ($metricHasPrefix) { "{0}{1}{2}" -f $metric.Name, $NameSeparator, $MarginsName } else { $MarginsName }
                    $ordered[$outputName] = Get-PSPandasPivotCellValue -Rows ([object[]]$group.Rows.ToArray()) -Metric $metric
                }
            }
            [void]$resultRows.Add([pscustomobject]$ordered)
        }

        if ($Margins -and $Index.Count -gt 0 -and $allRows.Count -gt 0) {
            $ordered = [ordered]@{}
            for ($indexPosition = 0; $indexPosition -lt $Index.Count; $indexPosition++) {
                $ordered[$Index[$indexPosition]] = if ($indexPosition -eq 0) { $MarginsName } else { $null }
            }
            foreach ($metric in $metrics) {
                foreach ($categoryKey in $categoryOrder) {
                    $category = $categoryInfo[$categoryKey]
                    $outputName = if ($metricHasPrefix) { "{0}{1}{2}" -f $metric.Name, $NameSeparator, $category.Label } else { $category.Label }
                    $ordered[$outputName] = Get-PSPandasPivotCellValue -Rows ([object[]]$category.Rows.ToArray()) -Metric $metric
                }
                $outputName = if ($metricHasPrefix) { "{0}{1}{2}" -f $metric.Name, $NameSeparator, $MarginsName } else { $MarginsName }
                $ordered[$outputName] = Get-PSPandasPivotCellValue -Rows ([object[]]$allRows.ToArray()) -Metric $metric
            }
            [void]$resultRows.Add([pscustomobject]$ordered)
        }

        $pivotMetadata = [pscustomobject][ordered]@{
            Index          = [string[]]$Index
            Columns        = [string[]]$Columns
            Metrics        = [object[]]@($metrics | ForEach-Object {
                [pscustomobject][ordered]@{ Name = $_.Name; Property = $_.Property; Function = $_.Function }
            })
            ColumnMap      = $columnMap
            NameSeparator  = $NameSeparator
            NullColumnName = $NullColumnName
            Margins        = [bool]$Margins
            MarginsName    = $MarginsName
            Layout         = if ($Outline) { 'Outline' } else { 'Table' }
            Grid           = [bool]$Grid
        }
        New-PSPandasDataFrameObject -Rows ([object[]]$resultRows.ToArray()) -Columns ([string[]]$outputColumns.ToArray()) -Metadata ([ordered]@{ Pivot = $pivotMetadata })
    }
}

Set-Alias -Name Pivot -Value ConvertTo-PSDataFrameWide
Set-Alias -Name Pivot-PSDataFrame -Value ConvertTo-PSDataFrameWide
