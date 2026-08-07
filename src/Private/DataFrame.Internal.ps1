function Test-PSPandasDataFrame {
    [CmdletBinding()]
    param([AllowNull()][object]$Value)

    return ($null -ne $Value -and @($Value.PSTypeNames) -contains 'PSPandas.DataFrame')
}

function Get-PSPandasPropertyValue {
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

function Import-PSPandasTypedFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$Path,
        [AllowNull()][object]$Schema,
        [ValidateRange(1, 1000000)][int]$SampleSize = 100,
        [ValidateSet('Auto', 'Present', 'None')][string]$HeaderMode = 'Auto',
        [ValidateSet('Header', 'Generic')][string]$NameMode = 'Header'
    )

    $reader = Get-Command -Name Import-FlatFile -ErrorAction SilentlyContinue
    if ($null -eq $reader) {
        throw "Cannot read '$Path' as a typed PSPandas data source because Import-FlatFile was not found. Import the PSFlatFile module before using file-path input."
    }

    $readerParameters = @{
        Path       = $Path
        SampleSize = $SampleSize
        HeaderMode = $HeaderMode
        NameMode   = $NameMode
    }
    if ($PSBoundParameters.ContainsKey('Schema')) {
        $readerParameters.Schema = $Schema
    }

    try {
        & $reader @readerParameters
    } catch {
        throw "Typed file reader Import-FlatFile failed for '$Path': $($_.Exception.Message)"
    }
}

function Import-PSPandasExcelRows {
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
    [CmdletBinding()]
    param(
        [AllowNull()][object[]]$Rows,
        [AllowEmptyCollection()][string[]]$Columns
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
    return [PSPandas.DataFrame]::new([string[]]$resolvedColumns.ToArray(), $rowsValue, $columnObjects.ToArray())
}

function Assert-PSPandasDataFrame {
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

    switch -Regex ($functionName.ToLowerInvariant()) {
        '^count$|^rowcount$' { return $(if ($propertyName) { @($values).Count } else { $rowArray.Count }) }
        '^sum$|^total$' {
            if (@($values).Count -eq 0) { return 0 }
            return [double](@($values | Measure-Object -Sum).Sum)
        }
        '^average$|^avg$|^mean$' {
            if (@($values).Count -eq 0) { return $null }
            return [double](@($values | Measure-Object -Average).Average)
        }
        '^minimum$|^min$' {
            if (@($values).Count -eq 0) { return $null }
            return (@($values | Measure-Object -Minimum).Minimum)
        }
        '^maximum$|^max$' {
            if (@($values).Count -eq 0) { return $null }
            return (@($values | Measure-Object -Maximum).Maximum)
        }
        default { throw "Unsupported aggregate function '$functionName'." }
    }
}
