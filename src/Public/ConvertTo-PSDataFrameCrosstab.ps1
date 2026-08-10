function ConvertTo-PSDataFrameCrosstab {
    <#
    .SYNOPSIS
    Creates a frequency cross-tabulation from a PSPandas data frame.

    .DESCRIPTION
    Counts rows for each combination of -Index and -Columns values and returns
    the result as a wide PSPandas DataFrame. Category order follows first
    appearance in the source data unless -Sort is specified. With -Normalize,
    count cells become proportions of all observations, of their index row, or
    of their column. The existing pivot engine supplies ordering, margins,
    multi-level dimensions, outline reports, and grid presentation.

    .PARAMETER DataFrame
    PSPandas DataFrame to cross-tabulate. The command accepts pipeline input.

    .PARAMETER Index
    One or more columns whose value combinations become output rows.

    .PARAMETER Columns
    One or more columns whose value combinations become output columns.

    .PARAMETER Margins
    Adds row and column totals.

    .PARAMETER MarginsName
    Label used for totals. Defaults to Total.

    .PARAMETER FillValue
    Value placed in cells for category combinations with no source rows. The
    default is integer zero because a crosstab represents frequencies. Pass
    an explicit `$null` to preserve blanks during normalization. Normalized
    crosstabs accept only zero or null fill values.

    .PARAMETER Normalize
    Converts counts to proportions. All divides by the total observations,
    Index divides each output row by its row total, and Columns divides each
    output column by its column total. Values are doubles. Normalize cannot be
    combined with Margins because normalized totals would have mixed meanings.

    .PARAMETER Percent
    Returns normalized proportions as percentage-point doubles from 0 to 100.
    Requires -Normalize. Interactive formatting shows the numeric
    percentage-point values without a suffix, while DataFrame rows retain
    numeric values.

    .PARAMETER Sort
    Sorts rendered index and category labels instead of preserving first-seen
    source order.

    .PARAMETER Outline
    Uses the pivot index metadata to render a hierarchical terminal report.

    .PARAMETER Grid
    Encloses an outline report in a width-calculated grid. Requires -Outline.

    .PARAMETER NameSeparator
    Separator used when flattening multiple dimensions. Defaults to an
    underscore.

    .PARAMETER NullColumnName
    Label used for null category values. Defaults to [null].

    .EXAMPLE
    $data | Crosstab -Index speaker -Columns utterance -Margins

    .EXAMPLE
    $sales | ConvertTo-PSDataFrameCrosstab -Index Region -Columns Channel -FillValue 0

    .EXAMPLE
    $sales | Crosstab -Index Region -Columns Channel -Normalize Index

    .OUTPUTS
    PSPandas.DataFrame
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true)]$DataFrame,
        [Parameter(Mandatory, Position = 0)][ValidateCount(1, 2147483647)][string[]]$Index,
        [Parameter(Mandatory, Position = 1)][Alias('Column')][ValidateCount(1, 2147483647)][string[]]$Columns,
        [AllowNull()][object]$FillValue,
        [ValidateSet('All', 'Index', 'Columns')][string]$Normalize,
        [switch]$Percent,
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

        if ($Normalize -and $Margins) {
            throw '-Normalize cannot be combined with -Margins because normalized totals have mixed meanings. Normalize the source or result separately if totals are needed.'
        }

        if ($Percent -and -not $Normalize) {
            throw '-Percent requires -Normalize All, -Normalize Index, or -Normalize Columns.'
        }

        if ($Normalize -and $PSBoundParameters.ContainsKey('FillValue') -and $null -ne $FillValue) {
            $numericFillTypes = @([byte], [sbyte], [int16], [uint16], [int32], [uint32], [int64], [uint64], [single], [double], [decimal])
            if ($FillValue.GetType() -notin $numericFillTypes -or [double]$FillValue -ne 0) {
                throw '-Normalize accepts only -FillValue 0 or -FillValue $null because other fill values cannot represent an absent proportion without distorting denominators.'
            }
        }

        $countColumn = '__PSPandasCrosstabCount'
        $suffix = 1
        while ($DataFrame.Columns -contains $countColumn) {
            $countColumn = '__PSPandasCrosstabCount' + $suffix
            $suffix++
        }

        $counted = Add-PSDataFrameColumn -DataFrame $DataFrame -Name $countColumn -Expression { 1 }
        $pivotParameters = @{
            DataFrame      = $counted
            Index          = $Index
            Columns        = $Columns
            Values         = $countColumn
            Aggregate      = 'Count'
            Margins        = $Margins
            MarginsName    = $MarginsName
            Sort           = $Sort
            Outline        = $Outline
            Grid           = $Grid
            NameSeparator  = $NameSeparator
            NullColumnName = $NullColumnName
        }
        if ($PSBoundParameters.ContainsKey('FillValue')) {
            $pivotParameters['FillValue'] = $FillValue
        } else {
            # Frequency tables are most useful at the terminal when absent
            # combinations read as zero rather than blank cells.
            $pivotParameters['FillValue'] = [int]0
        }

        $result = ConvertTo-PSDataFrameWide @pivotParameters
        if (-not $Normalize) {
            return $result
        }

        $resultRows = @($result.Rows)
        $dataColumns = @($result.Columns | Select-Object -Skip $Index.Count)
        $rowDenominators = [double[]]::new($resultRows.Count)
        $columnDenominators = [double[]]::new($dataColumns.Count)
        $allDenominator = [double]0

        for ($rowIndex = 0; $rowIndex -lt $resultRows.Count; $rowIndex++) {
            for ($columnIndex = 0; $columnIndex -lt $dataColumns.Count; $columnIndex++) {
                $value = Get-PSPandasPropertyValue -InputObject $resultRows[$rowIndex] -Name $dataColumns[$columnIndex]
                if ($null -eq $value) {
                    continue
                }
                try {
                    $number = [double]$value
                } catch {
                    throw "Cannot normalize crosstab cell '$($dataColumns[$columnIndex])' because value '$value' is not numeric."
                }
                $rowDenominators[$rowIndex] += $number
                $columnDenominators[$columnIndex] += $number
                $allDenominator += $number
            }
        }

        $normalizedRows = [System.Collections.Generic.List[object]]::new()
        Write-PSPandasProgress -Enabled -Activity 'PSPandas crosstab' -Status "Normalizing 0 of $($resultRows.Count) rows" -PercentComplete 50 -Id 6
        for ($rowIndex = 0; $rowIndex -lt $resultRows.Count; $rowIndex++) {
            $ordered = [ordered]@{}
            foreach ($indexName in $Index) {
                $ordered[$indexName] = Get-PSPandasPropertyValue -InputObject $resultRows[$rowIndex] -Name $indexName
            }
            for ($columnIndex = 0; $columnIndex -lt $dataColumns.Count; $columnIndex++) {
                $columnName = $dataColumns[$columnIndex]
                $value = Get-PSPandasPropertyValue -InputObject $resultRows[$rowIndex] -Name $columnName
                if ($null -eq $value) {
                    $ordered[$columnName] = $null
                    continue
                }

                $denominator = switch ($Normalize) {
                    'All' { $allDenominator; break }
                    'Index' { $rowDenominators[$rowIndex]; break }
                    'Columns' { $columnDenominators[$columnIndex]; break }
                }
                $ratio = if ($denominator -eq 0) { [double]0 } else { [double]$value / $denominator }
                $ordered[$columnName] = if ($Percent) { $ratio * 100.0 } else { $ratio }
            }
            [void]$normalizedRows.Add([pscustomobject]$ordered)
            if ($rowIndex -eq $resultRows.Count - 1 -or ($rowIndex + 1) % 50 -eq 0) {
                Write-PSPandasProgress -Enabled -Activity 'PSPandas crosstab' -Status "Normalized $($rowIndex + 1) of $($resultRows.Count) rows" -PercentComplete ([int](50 + (45 * (($rowIndex + 1) / [Math]::Max(1, $resultRows.Count))))) -Id 6
            }
        }

        $pivotMetadata = [ordered]@{}
        foreach ($property in $result.Metadata.Pivot.PSObject.Properties) {
            $pivotMetadata[$property.Name] = $property.Value
        }
        $pivotMetadata['Normalize'] = $Normalize
        $pivotMetadata['Percent'] = [bool]$Percent
        Write-PSPandasProgress -Enabled -Activity 'PSPandas crosstab' -Status 'Crosstab complete' -PercentComplete 100 -Id 6 -Completed
        New-PSPandasDataFrameObject -Rows ([object[]]$normalizedRows.ToArray()) -Columns ([string[]]$result.Columns) -Metadata ([ordered]@{ Pivot = [pscustomobject]$pivotMetadata })
    }
}

Set-Alias -Name Crosstab-PSDataFrame -Value ConvertTo-PSDataFrameCrosstab
Set-Alias -Name Crosstab -Value ConvertTo-PSDataFrameCrosstab
Set-Alias -Name xtab -Value ConvertTo-PSDataFrameCrosstab
