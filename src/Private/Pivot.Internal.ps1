function Resolve-PSPandasAggregateFunctionName {
    <#
    .SYNOPSIS
    Normalizes an aggregate function name to its canonical PSPandas name.

    .PARAMETER Name
    Aggregate name or supported synonym to normalize.

    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    switch ($Name.Trim().ToLowerInvariant()) {
        { $_ -in @('sum', 'total') } { return 'Sum' }
        { $_ -in @('count', 'rowcount') } { return 'Count' }
        { $_ -in @('average', 'avg', 'mean') } { return 'Average' }
        { $_ -in @('minimum', 'min') } { return 'Min' }
        { $_ -in @('maximum', 'max') } { return 'Max' }
        default { throw "Unsupported aggregate function '$Name'. Supported functions are Sum, Count, Average, Min, and Max." }
    }
}

function ConvertTo-PSPandasStableKey {
    <#
    .SYNOPSIS
    Serializes ordered values into a type-safe pivot key.

    .DESCRIPTION
    Uses type information and PowerShell serialization so null, DBNull, typed
    values, and values with identical display text remain distinguishable.

    .PARAMETER Values
    Ordered values that form a pivot row or column key.

    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    param([AllowNull()][object[]]$Values)

    $parts = foreach ($value in @($Values)) {
        if ($null -eq $value) {
            'null'
            continue
        }
        if ($value -is [System.DBNull]) {
            'dbnull'
            continue
        }

        $typeName = $value.GetType().AssemblyQualifiedName
        $serialized = [System.Management.Automation.PSSerializer]::Serialize($value, 3)
        $typeToken = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($typeName))
        $valueToken = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($serialized))
        "value:$typeToken`:$valueToken"
    }
    return ($parts -join '|')
}

function ConvertTo-PSPandasPivotValueLabel {
    <#
    .SYNOPSIS
    Converts one pivot dimension value into a deterministic display label.

    .PARAMETER Value
    Dimension value to render, including null and date-like values.

    .PARAMETER NullColumnName
    Label used for null or DBNull values.

    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory)][string]$NullColumnName
    )

    if ($null -eq $Value -or $Value -is [System.DBNull]) {
        return $NullColumnName
    }
    if ($Value -is [string] -and $Value.Length -eq 0) {
        return '[empty]'
    }
    if ($Value -is [datetime]) {
        if ($Value.TimeOfDay -eq [timespan]::Zero) {
            return $Value.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        }
        return $Value.ToString('yyyy-MM-ddTHH:mm:ss.fffffff', [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [datetimeoffset]) {
        return $Value.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value.GetType().FullName -eq 'System.DateOnly') {
        return $Value.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [System.IFormattable]) {
        return $Value.ToString($null, [Globalization.CultureInfo]::InvariantCulture)
    }
    return [string]$Value
}

function ConvertTo-PSPandasPivotTupleLabel {
    <#
    .SYNOPSIS
    Joins a composite pivot dimension into one deterministic label.

    .PARAMETER Values
    Ordered dimension values to label.

    .PARAMETER Separator
    Text inserted between dimension labels.

    .PARAMETER NullColumnName
    Label used for null or DBNull values.

    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][object[]]$Values,
        [Parameter(Mandatory)][string]$Separator,
        [Parameter(Mandatory)][string]$NullColumnName
    )

    $labels = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($Values)) {
        [void]$labels.Add((ConvertTo-PSPandasPivotValueLabel -Value $item -NullColumnName $NullColumnName))
    }
    return ($labels.ToArray() -join $Separator)
}

function Get-PSPandasPivotSpecificationProperty {
    <#
    .SYNOPSIS
    Resolves the source property for a pivot metric specification.

    .PARAMETER OutputName
    Name assigned to the output metric.

    .PARAMETER Specification
    Aggregate specification used by the metric.

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
    return Get-PSPandasAggregatePropertyName -OutputName $OutputName -Specification $Specification
}

function Resolve-PSPandasPivotMetrics {
    <#
    .SYNOPSIS
    Expands pivot value and aggregate arguments into metric definitions.

    .DESCRIPTION
    Handles identity pivots, uniform aggregate functions, per-value aggregate
    dictionaries, and advanced named specifications while validating source
    columns and generated metric names.

    .PARAMETER DataFrame
    Source PSPandas DataFrame.

    .PARAMETER Values
    Value columns supplied to the pivot command.

    .PARAMETER Aggregate
    Uniform aggregate value or ordered aggregate dictionary.

    .PARAMETER AggregateWasSpecified
    Indicates that aggregation is enabled rather than uniqueness enforcement.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$DataFrame,
        [AllowEmptyCollection()][string[]]$Values,
        [AllowNull()]$Aggregate,
        [switch]$AggregateWasSpecified
    )

    $metrics = [System.Collections.Generic.List[object]]::new()

    if (-not $AggregateWasSpecified) {
        if (@($Values).Count -eq 0) {
            throw 'Specify -Values when -Aggregate is omitted.'
        }
        Assert-PSPandasColumns -DataFrame $DataFrame -Columns $Values
        foreach ($propertyName in $Values) {
            [void]$metrics.Add([pscustomobject][ordered]@{
                Name          = [string]$propertyName
                Property      = [string]$propertyName
                Function      = $null
                Specification = $null
                IsIdentity    = $true
                IsAdvanced    = $false
            })
        }
        return $metrics.ToArray()
    }

    if ($null -eq $Aggregate) {
        throw '-Aggregate cannot be null. Omit it for a uniqueness-enforcing pivot.'
    }

    if ($Aggregate -is [System.Collections.IDictionary]) {
        if (@($Values).Count -gt 0) {
            throw 'Do not combine -Values with a dictionary -Aggregate. Dictionary keys or Property entries define the value columns.'
        }
        if ($Aggregate.Count -eq 0) {
            throw 'The -Aggregate dictionary cannot be empty.'
        }

        foreach ($entryNameValue in $Aggregate.Keys) {
            $entryName = [string]$entryNameValue
            if ([string]::IsNullOrWhiteSpace($entryName)) {
                throw 'Aggregate dictionary keys cannot be empty.'
            }
            $entrySpecification = $Aggregate[$entryNameValue]

            if ($entrySpecification -is [System.Collections.IDictionary] -or $entrySpecification -is [scriptblock]) {
                $propertyName = Get-PSPandasPivotSpecificationProperty -OutputName $entryName -Specification $entrySpecification
                if ($propertyName) {
                    Assert-PSPandasColumns -DataFrame $DataFrame -Columns @($propertyName)
                }

                $functionName = $null
                if ($entrySpecification -is [System.Collections.IDictionary]) {
                    if ($entrySpecification.Contains('Function')) {
                        $functionText = [string]$entrySpecification['Function']
                        if (-not [string]::IsNullOrWhiteSpace($functionText)) {
                            $functionName = Resolve-PSPandasAggregateFunctionName -Name $functionText
                        }
                    }
                    if (-not $functionName) {
                        $functionName = if ($propertyName) { 'Sum' } else { 'Count' }
                    }
                }

                [void]$metrics.Add([pscustomobject][ordered]@{
                    Name          = $entryName
                    Property      = $propertyName
                    Function      = $functionName
                    Specification = $entrySpecification
                    IsIdentity    = $false
                    IsAdvanced    = $true
                })
                continue
            }

            [object[]]$functions = @(if ($entrySpecification -is [string]) {
                    $entrySpecification
                } elseif ($entrySpecification -is [System.Collections.IEnumerable]) {
                    @($entrySpecification)
                } else {
                    throw "Aggregate entry '$entryName' must be a function name, an array of function names, a scriptblock, or a Property/Function dictionary."
                })
            if ($functions.Count -eq 0) {
                throw "Aggregate entry '$entryName' must specify at least one function."
            }

            Assert-PSPandasColumns -DataFrame $DataFrame -Columns @($entryName)
            foreach ($functionValue in $functions) {
                if ($functionValue -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$functionValue)) {
                    throw "Aggregate entry '$entryName' contains an invalid function name."
                }
                $functionName = Resolve-PSPandasAggregateFunctionName -Name ([string]$functionValue)
                $metricName = "{0}_{1}" -f $functionName, $entryName
                [void]$metrics.Add([pscustomobject][ordered]@{
                    Name          = $metricName
                    Property      = $entryName
                    Function      = $functionName
                    Specification = [ordered]@{ Property = $entryName; Function = $functionName }
                    IsIdentity    = $false
                    IsAdvanced    = $false
                })
            }
        }
        return $metrics.ToArray()
    }

    if (@($Values).Count -eq 0) {
        throw 'Specify -Values when -Aggregate is a function name or array of function names.'
    }
    Assert-PSPandasColumns -DataFrame $DataFrame -Columns $Values

    [object[]]$functions = @(if ($Aggregate -is [string]) { $Aggregate } else { @($Aggregate) })
    if ($functions.Count -eq 0) {
        throw '-Aggregate must specify at least one function.'
    }
    foreach ($functionValue in $functions) {
        if ($functionValue -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$functionValue)) {
            throw '-Aggregate values must be function names.'
        }
        $functionName = Resolve-PSPandasAggregateFunctionName -Name ([string]$functionValue)
        foreach ($propertyName in $Values) {
            [void]$metrics.Add([pscustomobject][ordered]@{
                Name          = ("{0}_{1}" -f $functionName, $propertyName)
                Property      = [string]$propertyName
                Function      = $functionName
                Specification = [ordered]@{ Property = [string]$propertyName; Function = $functionName }
                IsIdentity    = $false
                IsAdvanced    = $false
            })
        }
    }
    return $metrics.ToArray()
}

function Get-PSPandasPivotCellValue {
    <#
    .SYNOPSIS
    Calculates the value for one pivot cell.

    .PARAMETER Rows
    Source rows belonging to the pivot cell.

    .PARAMETER Metric
    Resolved metric definition describing identity or aggregate behavior.

    .OUTPUTS
    System.Object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Rows,
        [Parameter(Mandatory)]$Metric
    )

    if ($Metric.IsIdentity) {
        if ($Rows.Count -ne 1) {
            throw "Pivot values are not unique for value column '$($Metric.Property)'. Remove -Unique and use the default Sum, or specify -Aggregate, to combine duplicate index/column combinations."
        }
        return Get-PSPandasPropertyValue -InputObject $Rows[0] -Name $Metric.Property
    }

    return Invoke-PSPandasAggregate -Rows $Rows -Specification $Metric.Specification -OutputName $Metric.Name
}
