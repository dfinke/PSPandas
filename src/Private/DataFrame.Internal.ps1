function Test-PSPandasDataFrame {
    <#
    .SYNOPSIS
    Tests whether an object is a PSPandas DataFrame.

    .PARAMETER Value
    Object to examine. Null values return false.

    .OUTPUTS
    System.Boolean
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$Value)

    return ($null -ne $Value -and @($Value.PSTypeNames) -contains 'PSPandas.DataFrame')
}

function Get-PSPandasPropertyValue {
    <#
    .SYNOPSIS
    Reads a named value from an object or dictionary.

    .DESCRIPTION
    Provides one null-safe property accessor for dictionaries and PowerShell
    objects. Missing properties and null input produce null.

    .PARAMETER InputObject
    Object or dictionary from which to read the value.

    .PARAMETER Name
    Property or dictionary-key name to read.

    .OUTPUTS
    System.Object
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][object]$InputObject,
        [Parameter(Mandatory)][string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            return $InputObject[$Name]
        }
        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return $property.Value
    }
    return $null
}

function Get-PSPandasObjectColumns {
    <#
    .SYNOPSIS
    Returns the ordered column names exposed by an input object.

    .PARAMETER InputObject
    Dictionary or PowerShell object whose keys or properties define columns.

    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$InputObject)

    if ($null -eq $InputObject) {
        return @()
    }
    if ($InputObject -is [System.Collections.IDictionary]) {
        return @($InputObject.Keys | ForEach-Object { [string]$_ })
    }
    return @($InputObject.PSObject.Properties | ForEach-Object Name)
}

function ConvertTo-PSPandasRow {
    <#
    .SYNOPSIS
    Normalizes an input object into an ordered DataFrame row.

    .PARAMETER InputObject
    Source object. Missing values are represented by null.

    .PARAMETER Columns
    Ordered schema used to select and arrange row properties.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][object]$InputObject,
        [Parameter(Mandatory)][string[]]$Columns
    )

    $ordered = [ordered]@{}
    foreach ($column in $Columns) {
        $ordered[$column] = Get-PSPandasPropertyValue -InputObject $InputObject -Name $column
    }
    return [pscustomobject]$ordered
}

function ConvertTo-PSPandasColumnDataShape {
    <#
    .SYNOPSIS
    Converts column-oriented vectors into an ordered row-oriented shape.

    .DESCRIPTION
    Validates column names and vector lengths, preserves first-seen dictionary
    order and value types, and transposes vectors into ordered PowerShell rows.
    Scalar values are not broadcast.

    .PARAMETER ColumnData
    Dictionary whose keys are column names and whose values are arrays,
    enumerable collections, or PSPandas DataFrameColumn objects.

    .OUTPUTS
    System.Management.Automation.PSCustomObject with Columns and Rows properties.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$ColumnData)

    $columnNames = [System.Collections.Generic.List[string]]::new()
    $vectors = [System.Collections.Generic.List[object[]]]::new()
    $seenNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $expectedLength = $null
    $firstColumnName = $null

    foreach ($key in $ColumnData.Keys) {
        $columnName = [string]$key
        if ([string]::IsNullOrWhiteSpace($columnName)) {
            throw 'ColumnData column names cannot be empty.'
        }
        if (-not $seenNames.Add($columnName)) {
            throw "ColumnData contains duplicate column name '$columnName'."
        }

        $source = $ColumnData[$key]
        if ($source -is [PSPandas.DataFrameColumn]) {
            $source = $source.Values
        }
        if ($null -eq $source -or $source -is [string] -or
            $source -is [System.Collections.IDictionary] -or
            $source -isnot [System.Collections.IEnumerable]) {
            throw "ColumnData column '$columnName' must be an array or enumerable collection. Scalar values are not broadcast."
        }

        $values = [System.Collections.Generic.List[object]]::new()
        foreach ($value in $source) {
            [void]$values.Add($value)
        }
        $vector = [object[]]$values.ToArray()

        if ($null -eq $expectedLength) {
            $expectedLength = $vector.Count
            $firstColumnName = $columnName
        } elseif ($vector.Count -ne $expectedLength) {
            throw "ColumnData vectors must have the same length. Column '$columnName' has $($vector.Count) values; expected $expectedLength based on column '$firstColumnName'."
        }

        [void]$columnNames.Add($columnName)
        [void]$vectors.Add($vector)
    }

    $rowCount = if ($null -eq $expectedLength) { 0 } else { $expectedLength }
    $rows = [System.Collections.Generic.List[object]]::new()
    for ($rowIndex = 0; $rowIndex -lt $rowCount; $rowIndex++) {
        $ordered = [ordered]@{}
        for ($columnIndex = 0; $columnIndex -lt $columnNames.Count; $columnIndex++) {
            $ordered[$columnNames[$columnIndex]] = $vectors[$columnIndex][$rowIndex]
        }
        [void]$rows.Add([pscustomobject]$ordered)
    }

    return [pscustomobject][ordered]@{
        Columns = [string[]]$columnNames.ToArray()
        Rows    = [object[]]$rows.ToArray()
    }
}

function Import-PSPandasTypedFile {
    <#
    .SYNOPSIS
    Reads a flat file through PSPandas' native typed delimited-file reader.

    .DESCRIPTION
    Supports common comma, pipe, semicolon, and tab-delimited files without a
    runtime dependency on PSFlatFile or Import-Csv.

    .PARAMETER Path
    Existing flat-file path to read.

    .PARAMETER Schema
    Optional native delimited schema.

    .PARAMETER SampleSize
    Maximum number of nonempty records used for inference.

    .PARAMETER HeaderMode
    Header handling mode.

    .PARAMETER NameMode
    Inferred property-name mode.

    .OUTPUTS
    System.Object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$Path,
        [AllowNull()][object]$Schema,
        [ValidateRange(1, 1000000)][int]$SampleSize = 100,
        [ValidateSet('Auto', 'Present', 'None')][string]$HeaderMode = 'Auto',
        [ValidateSet('Header', 'Generic')][string]$NameMode = 'Header'
    )

    $readerParameters = @{
        Path       = $Path
        SampleSize = $SampleSize
        HeaderMode = $HeaderMode
        NameMode   = $NameMode
    }
    if ($PSBoundParameters.ContainsKey('Schema')) {
        $readerParameters.Schema = $Schema
    }

    Import-PSPandasNativeDelimitedFile @readerParameters
}

function Import-PSPandasExcelRows {
    <#
    .SYNOPSIS
    Reads one Excel worksheet through an ImportExcel command reference.

    .PARAMETER Path
    Workbook path passed to Import-Excel.

    .PARAMETER Reader
    Resolved Import-Excel command to invoke.

    .PARAMETER WorksheetName
    Optional worksheet name. When omitted, the reader's first-sheet behavior
    is preserved.

    .OUTPUTS
    System.Object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Reader,
        [AllowNull()][string]$WorksheetName
    )

    $readerParameters = @{ Path = $Path }
    $worksheetDescription = 'first worksheet'
    if (-not [string]::IsNullOrWhiteSpace($WorksheetName)) {
        $readerParameters.WorksheetName = $WorksheetName
        $worksheetDescription = "worksheet '$WorksheetName'"
    }

    try {
        return @(& $Reader @readerParameters)
    } catch {
        throw "Excel reader Import-Excel failed for '$Path' $worksheetDescription`: $($_.Exception.Message)"
    }
}

function New-PSPandasDataFrameObject {
    <#
    .SYNOPSIS
    Creates a normalized PSPandas DataFrame object.

    .DESCRIPTION
    Resolves an ordered schema, normalizes every row to that schema, creates
    indexed column objects, and copies optional transformation metadata.

    .PARAMETER Rows
    Source rows. Null is treated as an empty row collection.

    .PARAMETER Columns
    Optional ordered schema. When empty, columns are discovered in first-seen
    order across source rows.

    .PARAMETER Metadata
    Optional ordered metadata copied onto the resulting DataFrame.

    .OUTPUTS
    PSPandas.DataFrame
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][object[]]$Rows,
        [AllowEmptyCollection()][string[]]$Columns,
        [AllowNull()][System.Collections.IDictionary]$Metadata
    )

    $sourceRows = if ($null -eq $Rows) { @() } else { @($Rows) }
    $resolvedColumns = [System.Collections.Generic.List[string]]::new()
    foreach ($column in @($Columns)) {
        if ($null -eq $column) {
            continue
        }
        if ([string]::IsNullOrWhiteSpace($column)) {
            throw 'Data-frame column names cannot be empty.'
        }
        if (-not $resolvedColumns.Contains($column)) {
            [void]$resolvedColumns.Add($column)
        }
    }

    if ($resolvedColumns.Count -eq 0) {
        foreach ($row in $sourceRows) {
            foreach ($column in @(Get-PSPandasObjectColumns -InputObject $row)) {
                if (-not $resolvedColumns.Contains($column)) {
                    [void]$resolvedColumns.Add($column)
                }
            }
        }
    }

    $normalizedRows = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $sourceRows) {
        [void]$normalizedRows.Add((ConvertTo-PSPandasRow -InputObject $row -Columns $resolvedColumns.ToArray()))
    }

    $rowsValue = if ($normalizedRows.Count -eq 0) {
        [object[]]::new(0)
    } else {
        [object[]]$normalizedRows.ToArray()
    }

    $columnObjects = [System.Collections.Generic.List[PSPandas.DataFrameColumn]]::new()
    foreach ($column in $resolvedColumns) {
        $columnValues = [System.Collections.Generic.List[object]]::new()
        foreach ($row in $rowsValue) {
            [void]$columnValues.Add((Get-PSPandasPropertyValue -InputObject $row -Name $column))
        }
        [void]$columnObjects.Add([PSPandas.DataFrameColumn]::new($column, [object[]]$columnValues.ToArray()))
    }
    $dataFrame = [PSPandas.DataFrame]::new([string[]]$resolvedColumns.ToArray(), $rowsValue, $columnObjects.ToArray())
    if ($null -ne $Metadata) {
        $metadataCopy = [ordered]@{}
        foreach ($name in $Metadata.Keys) {
            $metadataCopy[[string]$name] = $Metadata[$name]
        }
        $dataFrame | Add-Member -MemberType NoteProperty -Name Metadata -Value $metadataCopy
    }
    return $dataFrame
}

function Assert-PSPandasDataFrame {
    <#
    .SYNOPSIS
    Validates that a value is a PSPandas DataFrame.

    .PARAMETER DataFrame
    Value to validate.

    .PARAMETER ParameterName
    Parameter name included in the validation error.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$DataFrame,
        [string]$ParameterName = 'DataFrame'
    )

    if (-not (Test-PSPandasDataFrame -Value $DataFrame)) {
        throw "Parameter '$ParameterName' must be a PSPandas data frame. Create one with ConvertTo-PSDataFrame."
    }
}

function New-PSPandasWorkbookObject {
    <#
    .SYNOPSIS
    Creates a tab-completable PSPandas workbook wrapper.

    .PARAMETER Path
    Source workbook path recorded on the wrapper.

    .PARAMETER Worksheets
    Ordered objects containing Name and DataFrame properties.

    .OUTPUTS
    PSPandas.Workbook
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object[]]$Worksheets
    )

    $names = [string[]]@($Worksheets | ForEach-Object { $_.Name })
    $frames = [object[]]@($Worksheets | ForEach-Object { $_.DataFrame })
    return [PSPandas.Workbook]::new($Path, $names, $frames)
}

function Assert-PSPandasColumns {
    <#
    .SYNOPSIS
    Validates that requested columns exist in a DataFrame.

    .PARAMETER DataFrame
    PSPandas DataFrame whose schema is checked.

    .PARAMETER Columns
    Column names that must exist.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$DataFrame,
        [Parameter(Mandatory)][string[]]$Columns
    )

    foreach ($column in $Columns) {
        if ($DataFrame.Columns -notcontains $column) {
            throw "Column '$column' does not exist in the data frame."
        }
    }
}

function Get-PSPandasGroupKey {
    <#
    .SYNOPSIS
    Produces a stable internal key for grouped values.

    .DESCRIPTION
    Encodes value type, text length, and text representation so values with
    similar display text but different types remain distinct.

    .PARAMETER Values
    Ordered values that make up the group key.

    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    param([AllowNull()][object[]]$Values)

    $parts = foreach ($value in @($Values)) {
        if ($null -eq $value) {
            '<null>'
        } else {
            $text = [string]$value
            "{0}:{1}:{2}" -f $value.GetType().FullName, $text.Length, $text
        }
    }
    return ($parts -join '|')
}

function Get-PSPandasGroupKeyObject {
    <#
    .SYNOPSIS
    Creates the public key value returned for a group.

    .PARAMETER Row
    Representative row from the group.

    .PARAMETER By
    Ordered grouping columns. One column returns a scalar; multiple columns
    return an ordered object.

    .OUTPUTS
    System.Object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Row,
        [Parameter(Mandatory)][string[]]$By
    )

    if ($By.Count -eq 1) {
        return Get-PSPandasPropertyValue -InputObject $Row -Name $By[0]
    }
    $ordered = [ordered]@{}
    foreach ($column in $By) {
        $ordered[$column] = Get-PSPandasPropertyValue -InputObject $Row -Name $column
    }
    return [pscustomobject]$ordered
}

function Get-PSPandasAggregatePropertyName {
    <#
    .SYNOPSIS
    Resolves the source property used by an aggregate specification.

    .PARAMETER OutputName
    Aggregate output name, also used as the inferred source property when a
    non-count dictionary specification omits Property.

    .PARAMETER Specification
    Scriptblock, property-name string, or Property/Function dictionary.

    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$OutputName,
        [Parameter(Mandatory)]$Specification
    )

    if ($Specification -is [scriptblock]) {
        return $null
    }
    if ($Specification -is [string]) {
        if ($Specification -in @('Count', 'RowCount')) {
            return $null
        }
        return $Specification
    }
    if ($Specification -is [System.Collections.IDictionary]) {
        $propertyName = if ($Specification.Contains('Property')) { [string]$Specification['Property'] } else { $null }
        if (-not [string]::IsNullOrWhiteSpace($propertyName)) {
            return $propertyName
        }

        $functionName = if ($Specification.Contains('Function')) { [string]$Specification['Function'] } else { 'Count' }
        if ($functionName -in @('Count', 'RowCount')) {
            return $null
        }
        return $OutputName
    }

    throw 'Aggregate specifications must be scriptblocks, property names, or hashtables with Property and Function keys.'
}

function Invoke-PSPandasAggregate {
    <#
    .SYNOPSIS
    Evaluates one aggregate specification against a row collection.

    .DESCRIPTION
    Supports custom scriptblocks and the Count, Sum, Average, Min, and Max
    built-ins while preserving the module's empty-input semantics.

    .PARAMETER Rows
    Rows in the current group.

    .PARAMETER Specification
    Aggregate scriptblock, property-name string, or dictionary specification.

    .PARAMETER OutputName
    Name of the output column being calculated.

    .OUTPUTS
    System.Object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Rows,
        [Parameter(Mandatory)]$Specification,
        [Parameter(Mandatory)][string]$OutputName
    )

    $rowArray = @($Rows)

    if ($Specification -is [scriptblock]) {
        return (& $Specification $rowArray)
    }

    $propertyName = Get-PSPandasAggregatePropertyName -OutputName $OutputName -Specification $Specification
    $functionName = $null
    if ($Specification -is [string]) {
        if ($Specification -in @('Count', 'RowCount')) {
            return $rowArray.Count
        }
        $functionName = 'Sum'
    } elseif ($Specification -is [System.Collections.IDictionary]) {
        if ($Specification.Contains('Function')) {
            $functionName = [string]$Specification['Function']
        }
        if ([string]::IsNullOrWhiteSpace($functionName)) {
            $functionName = if ($propertyName) { 'Sum' } else { 'Count' }
        }
    }

    $values = if ($propertyName) {
        @($Rows | ForEach-Object { Get-PSPandasPropertyValue -InputObject $_ -Name $propertyName } | Where-Object { $null -ne $_ })
    } else {
        $rowArray
    }

    $functionName = Resolve-PSPandasAggregateFunctionName -Name $functionName
    switch ($functionName) {
        'Count' { return $(if ($propertyName) { @($values).Count } else { $rowArray.Count }) }
        'Sum' {
            if (@($values).Count -eq 0) { return 0 }
            return [double](@($values | Measure-Object -Sum).Sum)
        }
        'Average' {
            if (@($values).Count -eq 0) { return $null }
            return [double](@($values | Measure-Object -Average).Average)
        }
        'Min' {
            if (@($values).Count -eq 0) { return $null }
            return (@($values | Measure-Object -Minimum).Minimum)
        }
        'Max' {
            if (@($values).Count -eq 0) { return $null }
            return (@($values | Measure-Object -Maximum).Maximum)
        }
    }
}
