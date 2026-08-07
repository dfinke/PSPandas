function ConvertTo-PSDataFrame {
    <#
    .SYNOPSIS
    Creates a PSPandas data frame from pipeline objects.

    .DESCRIPTION
    Ordinary PowerShell objects, dictionaries, and existing PSPandas frames are
    supported. An explicit column list can define an empty or stable schema.
    A file path uses the typed Import-FlatFile reader from PSFlatFile; no
    untyped Import-Csv fallback is used.

    .PARAMETER InputObject
    Ordinary objects, dictionaries, or existing PSPandas DataFrames collected
    from the pipeline into the new frame.

    .PARAMETER Path
    Path to a file read through the typed Import-FlatFile reader from PSFlatFile.

    .PARAMETER Schema
    Optional schema passed to Import-FlatFile.

    .PARAMETER SampleSize
    Maximum number of nonempty file lines used by Import-FlatFile inference.

    .PARAMETER HeaderMode
    Header handling passed to Import-FlatFile.

    .PARAMETER NameMode
    Inferred property-name mode passed to Import-FlatFile.

    .PARAMETER Columns
    Optional ordered schema. It defines empty frames and normalizes input rows
    to a stable set and order of properties.

    .EXAMPLE
    Import-Csv .\orders.csv | ConvertTo-PSDataFrame

    .EXAMPLE
    ConvertTo-PSDataFrame .\orders.csv

    .OUTPUTS
    PSPandas.DataFrame
    #>
    [CmdletBinding(DefaultParameterSetName = 'InputObject')]
    param(
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'InputObject')][AllowNull()][object]$InputObject,
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Path')][string]$Path,
        [Parameter(ParameterSetName = 'Path')][AllowNull()][object]$Schema,
        [Parameter(ParameterSetName = 'Path')][ValidateRange(1, 1000000)][int]$SampleSize = 100,
        [Parameter(ParameterSetName = 'Path')][ValidateSet('Auto', 'Present', 'None')][string]$HeaderMode = 'Auto',
        [Parameter(ParameterSetName = 'Path')][ValidateSet('Header', 'Generic')][string]$NameMode = 'Header',
        [string[]]$Columns
    )
    begin { $items = [System.Collections.Generic.List[object]]::new() }
    process {
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            return
        }
        if (Test-PSPandasDataFrame -Value $InputObject) {
            foreach ($row in @($InputObject.Rows)) { [void]$items.Add($row) }
        } else {
            [void]$items.Add($InputObject)
        }
    }
    end {
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $readerParameters = @{
                Path       = $Path
                SampleSize = $SampleSize
                HeaderMode = $HeaderMode
                NameMode   = $NameMode
            }
            if ($PSBoundParameters.ContainsKey('Schema')) {
                $readerParameters.Schema = $Schema
            }
            $typedRows = @(Import-PSPandasTypedFile @readerParameters)
            New-PSPandasDataFrameObject -Rows $typedRows -Columns $Columns
            return
        }

        New-PSPandasDataFrameObject -Rows $items.ToArray() -Columns $Columns
    }
}
