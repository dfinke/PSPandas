function ConvertTo-PSDataFrameConcat {
    <#
    .SYNOPSIS
    Concatenates PSPandas data frames vertically.

    .DESCRIPTION
    Appends the rows from two or more PSPandas data frames in input order.
    Output columns are the union of source columns in first-seen order unless
    -Sort is supplied. Missing columns are populated with null values, and an
    empty source frame contributes its declared schema.

    This command models the common pandas concat(..., axis=0) operation. It
    does not perform key matching; use Join-PSDataFrame for keyed combining.

    .PARAMETER DataFrame
    One or more PSPandas data frames to concatenate. The parameter accepts
    direct arrays and pipeline input.

    .PARAMETER Sort
    Sorts the union of output columns alphabetically instead of preserving
    first-seen source order.

    .EXAMPLE
    $combined = Concat-PSDataFrame -DataFrame $orders2025, $orders2026

    .EXAMPLE
    $combined = $orders2025, $orders2026 | Concat

    .EXAMPLE
    $combined = $left, $right | Concat -Sort

    .OUTPUTS
    PSPandas.DataFrame
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline = $true)]
        [object[]]$DataFrame,
        [switch]$Sort
    )

    begin {
        $frames = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($candidate in @($DataFrame)) {
            Assert-PSPandasDataFrame -DataFrame $candidate -ParameterName 'DataFrame'
            [void]$frames.Add($candidate)
        }
    }

    end {
        if ($frames.Count -eq 0) {
            throw 'Concat requires at least one PSPandas data frame.'
        }

        $columns = [System.Collections.Generic.List[string]]::new()
        foreach ($frame in $frames) {
            foreach ($column in @($frame.Columns)) {
                if (-not $columns.Contains($column)) {
                    [void]$columns.Add($column)
                }
            }
        }

        $outputColumns = if ($Sort) {
            [string[]]@($columns | Sort-Object)
        } else {
            [string[]]$columns.ToArray()
        }

        $rows = [System.Collections.Generic.List[object]]::new()
        foreach ($frame in $frames) {
            foreach ($row in @($frame.Rows)) {
                [void]$rows.Add($row)
            }
        }

        New-PSPandasDataFrameObject -Rows ([object[]]$rows.ToArray()) -Columns $outputColumns
    }
}

Set-Alias -Name Concat-PSDataFrame -Value ConvertTo-PSDataFrameConcat
Set-Alias -Name Concat -Value ConvertTo-PSDataFrameConcat
