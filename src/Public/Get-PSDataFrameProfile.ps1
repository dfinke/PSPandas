function Get-PSDataFrameProfile {
    <#
    .SYNOPSIS
    Profiles each column in a PSPandas data frame.

    .DESCRIPTION
    Returns a PSPandas data frame with one row per source column. Null values
    are counted and omitted from distinct counts, samples, and applicable
    summaries. Numeric and date summaries are populated only when all
    non-null values are compatible. Mixed, empty, and all-null columns remain
    profileable without throwing.

    .PARAMETER SampleCount
    Maximum number of non-null sample values retained per column.

    .EXAMPLE
    Import-Csv .\orders.csv | ConvertTo-PSDataFrame | Describe
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true)]$DataFrame,
        [ValidateRange(0, 100)][int]$SampleCount = 3
    )
    process {
        Assert-PSPandasDataFrame -DataFrame $DataFrame

        $profileColumns = @(
            'Column', 'Type', 'RowCount', 'NullCount', 'DistinctCount',
            'SampleValues', 'Minimum', 'Maximum', 'Average', 'Sum',
            'Earliest', 'Latest'
        )
        $profileRows = [System.Collections.Generic.List[object]]::new()

        foreach ($column in $DataFrame.Columns) {
            $rawValues = [System.Collections.Generic.List[object]]::new()
            foreach ($row in @($DataFrame.Rows)) {
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
                    if ($typeNames -contains 'DateTimeOffset' -and $typeNames.Count -eq 1) { 'DateTimeOffset' } else { 'DateTime' }
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
            } elseif ($nonNullValues.Count -gt 0 -and $type -in @('DateTime', 'DateTimeOffset')) {
                $earliest = $nonNullValues[0]
                $latest = $nonNullValues[0]
                $earliestComparable = [DateTimeOffset]$earliest
                $latestComparable = $earliestComparable
                foreach ($value in @($nonNullValues | Select-Object -Skip 1)) {
                    $comparable = [DateTimeOffset]$value
                    if ($comparable -lt $earliestComparable) {
                        $earliest = $value
                        $earliestComparable = $comparable
                    }
                    if ($comparable -gt $latestComparable) {
                        $latest = $value
                        $latestComparable = $comparable
                    }
                }
            }

            [void]$profileRows.Add([pscustomobject][ordered]@{
                Column        = $column
                Type          = $type
                RowCount      = $rawValues.Count
                NullCount     = $nullCount
                DistinctCount = $distinctValues.Count
                SampleValues  = [object[]]$samples.ToArray()
                Minimum       = $minimum
                Maximum       = $maximum
                Average       = $average
                Sum           = $sum
                Earliest      = $earliest
                Latest        = $latest
            })
        }

        $profileFrame = New-PSPandasDataFrameObject -Rows $profileRows.ToArray() -Columns $profileColumns
        [void]$profileFrame.PSTypeNames.Insert(0, 'PSPandas.Profile')
        $profileFrame
    }
}

function Test-PSDataFrameProfileNumericType {
    [CmdletBinding()]
    param([Parameter(Mandatory)][type]$Type)

    return $Type -in @(
        [byte], [sbyte], [short], [ushort], [int], [uint], [long], [ulong],
        [single], [double], [decimal]
    )
}

function Test-PSDataFrameProfileDateType {
    [CmdletBinding()]
    param([Parameter(Mandatory)][type]$Type)

    return $Type -in @([datetime], [datetimeoffset])
}

Set-Alias -Name Describe -Value Get-PSDataFrameProfile
