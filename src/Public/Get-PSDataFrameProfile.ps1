function Get-PSDataFrameProfile {
    <#
    .SYNOPSIS
    Profiles each column in a PSPandas data frame.

    .DESCRIPTION
    Returns a PSPandas data frame with one row per source column. Null values
    are counted and omitted from distinct counts, samples, and applicable
    summaries. Numeric and date summaries are populated only when all
    non-null values are compatible. Mixed, empty, and all-null columns remain
    profileable without throwing. A file path uses PSPandas' native typed
    delimited reader; no external PSFlatFile dependency or untyped Import-Csv
    fallback is used. An HTTP or HTTPS URI is downloaded and passed through
    the same reader.

    .PARAMETER DataFrame
    PSPandas DataFrame received from the pipeline and profiled in memory.

    .PARAMETER SampleCount
    Maximum number of non-null sample values retained per column.

    .PARAMETER AsRows
    Emits ordinary profile-row objects instead of the default profile DataFrame.

    .PARAMETER Path
    Path to a common delimited file read through PSPandas' native typed reader.

    .PARAMETER Uri
    Absolute HTTP or HTTPS URI downloaded and read through the native typed
    reader.

    .PARAMETER TimeoutSec
    Maximum number of seconds allowed for an HTTP or HTTPS download. The
    default is 30 seconds.

    .PARAMETER Schema
    Optional schema for native delimited-file type conversion.

    .PARAMETER SampleSize
    Maximum number of nonempty file lines used by native type inference.

    .PARAMETER HeaderMode
    Header handling used by native delimited-file inference.

    .PARAMETER NameMode
    Inferred property-name mode used by the native delimited reader.

    .EXAMPLE
    Describe .\orders.csv

    .EXAMPLE
    Describe -Uri 'https://example.com/orders.csv' -AsRows

    .EXAMPLE
    $data | Describe -AsRows | Where-Object Type -eq 'DateTime'

    .EXAMPLE
    Describe .\orders.csv

    .OUTPUTS
    PSPandas.DataFrame by default. With AsRows, emits ordinary PowerShell
    profile-row objects.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true, ParameterSetName = 'DataFrame')]$DataFrame,
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Path')][string]$Path,
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Uri')][uri]$Uri,
        [Parameter(ParameterSetName = 'Uri')][ValidateRange(1, 600)][int]$TimeoutSec = 30,
        [ValidateRange(0, 100)][int]$SampleCount = 3,
        [switch]$AsRows,
        [Parameter(ParameterSetName = 'Path')][Parameter(ParameterSetName = 'Uri')][AllowNull()][object]$Schema,
        [Parameter(ParameterSetName = 'Path')][Parameter(ParameterSetName = 'Uri')][ValidateRange(1, 1000000)][int]$SampleSize = 100,
        [Parameter(ParameterSetName = 'Path')][Parameter(ParameterSetName = 'Uri')][ValidateSet('Auto', 'Present', 'None')][string]$HeaderMode = 'Auto',
        [Parameter(ParameterSetName = 'Path')][Parameter(ParameterSetName = 'Uri')][ValidateSet('Header', 'Generic')][string]$NameMode = 'Header'
    )
    process {
        if ($PSCmdlet.ParameterSetName -in @('Path', 'Uri')) {
            $readerParameters = @{
                SampleSize = $SampleSize
                HeaderMode = $HeaderMode
                NameMode   = $NameMode
            }
            if ($PSCmdlet.ParameterSetName -eq 'Uri') { $readerParameters.Uri = $Uri } else { $readerParameters.Path = $Path }
            if ($PSCmdlet.ParameterSetName -eq 'Uri') { $readerParameters.TimeoutSec = $TimeoutSec }
            if ($PSBoundParameters.ContainsKey('Schema')) {
                $readerParameters.Schema = $Schema
            }
            $sourceDataFrame = ConvertTo-PSDataFrame @readerParameters
        } else {
            $sourceDataFrame = $DataFrame
        }

        Assert-PSPandasDataFrame -DataFrame $sourceDataFrame

        $profileColumns = @(
            'Column', 'Type', 'RowCount', 'NullCount', 'DistinctCount',
            'Minimum', 'Maximum', 'Average', 'Sum', 'SampleValues',
            'Earliest', 'Latest'
        )
        $profileRows = [System.Collections.Generic.List[object]]::new()

        $columnCount = @($sourceDataFrame.Columns).Count
        $columnIndex = 0
        Write-PSPandasProgress -Enabled -Activity 'PSPandas profile' -Status "Profiling 0 of $columnCount columns" -PercentComplete 0 -Id 4
        foreach ($column in $sourceDataFrame.Columns) {
            $columnIndex++
            Write-PSPandasProgress -Enabled -Activity 'PSPandas profile' -Status "Profiling column $columnIndex of ${columnCount}: $column" -PercentComplete ([int](90 * ($columnIndex / [Math]::Max(1, $columnCount)))) -Id 4
            $rawValues = [System.Collections.Generic.List[object]]::new()
            foreach ($row in @($sourceDataFrame.Rows)) {
                [void]$rawValues.Add((Get-PSPandasPropertyValue -InputObject $row -Name $column))
            }

            $nonNullValues = [System.Collections.Generic.List[object]]::new()
            $nullCount = 0
            foreach ($value in $rawValues) {
                if ($null -eq $value -or $value -is [DBNull]) {
                    $nullCount++
                } else {
                    [void]$nonNullValues.Add($value)
                }
            }

            $distinctValues = [System.Collections.Generic.List[object]]::new()
            foreach ($value in $nonNullValues) {
                $found = $false
                foreach ($existing in $distinctValues) {
                    if ([object]::Equals($existing, $value)) {
                        $found = $true
                        break
                    }
                }
                if (-not $found) {
                    [void]$distinctValues.Add($value)
                }
            }

            $samples = [System.Collections.Generic.List[object]]::new()
            $sampleLimit = [Math]::Min($SampleCount, $nonNullValues.Count)
            for ($sampleIndex = 0; $sampleIndex -lt $sampleLimit; $sampleIndex++) {
                [void]$samples.Add($nonNullValues[$sampleIndex])
            }

            $type = if ($nonNullValues.Count -eq 0) {
                if ($rawValues.Count -eq 0) { 'Empty' } else { 'Null' }
            } else {
                $allNumeric = $true
                $allDateLike = $true
                $typeNames = [System.Collections.Generic.List[string]]::new()
                foreach ($value in $nonNullValues) {
                    $valueType = $value.GetType()
                    if ($typeNames -notcontains $valueType.Name) {
                        [void]$typeNames.Add($valueType.Name)
                    }
                    if (-not (Test-PSDataFrameProfileNumericType -Type $valueType)) {
                        $allNumeric = $false
                    }
                    if (-not (Test-PSDataFrameProfileDateType -Type $valueType)) {
                        $allDateLike = $false
                    }
                }
                if ($allNumeric) {
                    'Numeric'
                } elseif ($allDateLike) {
                    if ($typeNames.Count -eq 1) { $typeNames[0] } else { 'DateTime' }
                } elseif ($typeNames.Count -eq 1) {
                    $typeNames[0]
                } else {
                    'Mixed'
                }
            }

            $minimum = $null
            $maximum = $null
            $average = $null
            $sum = $null
            $earliest = $null
            $latest = $null

            if ($nonNullValues.Count -gt 0 -and $type -eq 'Numeric') {
                $numericValues = [System.Collections.Generic.List[double]]::new()
                foreach ($value in $nonNullValues) {
                    [void]$numericValues.Add([Convert]::ToDouble($value, [Globalization.CultureInfo]::InvariantCulture))
                }
                $minimum = $numericValues[0]
                $maximum = $numericValues[0]
                $sum = 0d
                foreach ($number in $numericValues) {
                    if ($number -lt $minimum) { $minimum = $number }
                    if ($number -gt $maximum) { $maximum = $number }
                    $sum += $number
                }
                $average = $sum / $numericValues.Count
            } elseif ($nonNullValues.Count -gt 0 -and $type -in @('DateTime', 'DateTimeOffset', 'DateOnly')) {
                $minimum = $nonNullValues[0]
                $maximum = $nonNullValues[0]
                $earliestComparable = ConvertTo-PSDataFrameProfileDateComparable -Value $minimum
                $latestComparable = $earliestComparable
                foreach ($value in @($nonNullValues | Select-Object -Skip 1)) {
                    $comparable = ConvertTo-PSDataFrameProfileDateComparable -Value $value
                    if ($comparable -lt $earliestComparable) {
                        $minimum = $value
                        $earliestComparable = $comparable
                    }
                    if ($comparable -gt $latestComparable) {
                        $maximum = $value
                        $latestComparable = $comparable
                    }
                }
                $earliest = $minimum
                $latest = $maximum
            }

            $profileRow = [pscustomobject][ordered]@{
                Column        = $column
                Type          = $type
                RowCount      = $rawValues.Count
                NullCount     = $nullCount
                DistinctCount = $distinctValues.Count
                Minimum       = $minimum
                Maximum       = $maximum
                Average       = $average
                Sum           = $sum
                SampleValues  = [object[]]$samples.ToArray()
                Earliest      = $earliest
                Latest        = $latest
            }
            [void]$profileRow.PSTypeNames.Insert(0, 'PSPandas.ProfileRow')
            [void]$profileRows.Add($profileRow)
        }

        Write-PSPandasProgress -Enabled -Activity 'PSPandas profile' -Status 'Profile complete' -PercentComplete 100 -Id 4 -Completed

        $profileFrame = New-PSPandasDataFrameObject -Rows $profileRows.ToArray() -Columns $profileColumns
        [void]$profileFrame.PSTypeNames.Insert(0, 'PSPandas.Profile')
        foreach ($profileRow in @($profileFrame.Rows)) {
            [void]$profileRow.PSTypeNames.Insert(0, 'PSPandas.ProfileRow')
        }

        if ($AsRows) {
            foreach ($profileRow in @($profileFrame.Rows)) {
                Write-Output $profileRow
            }
            return
        }

        $profileFrame
    }
}

function Test-PSDataFrameProfileNumericType {
    <#
    .SYNOPSIS
    Tests whether a .NET type is supported as a numeric profile value.

    .PARAMETER Type
    Runtime type to classify.

    .OUTPUTS
    System.Boolean
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][type]$Type)

    return $Type -in @(
        [byte], [sbyte], [short], [ushort], [int], [uint], [long], [ulong],
        [single], [double], [decimal]
    )
}

function Test-PSDataFrameProfileDateType {
    <#
    .SYNOPSIS
    Tests whether a .NET type is supported as a date-like profile value.

    .PARAMETER Type
    Runtime type to classify.

    .OUTPUTS
    System.Boolean
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][type]$Type)

    return $Type -in @([datetime], [datetimeoffset], [System.DateOnly])
}

function ConvertTo-PSDataFrameProfileDateComparable {
    <#
    .SYNOPSIS
    Converts a supported date-like value into a comparable representation.

    .PARAMETER Value
    DateTime, DateTimeOffset, or DateOnly value to normalize for comparison.

    .OUTPUTS
    System.DateTimeOffset
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Value)

    if ($Value -is [System.DateOnly]) {
        return $Value.ToDateTime([System.TimeOnly]::MinValue)
    }
    if ($Value -is [System.DateTimeOffset]) {
        return [System.DateTimeOffset]$Value
    }
    return [System.DateTimeOffset]$Value
}

Set-Alias -Name Describe -Value Get-PSDataFrameProfile
