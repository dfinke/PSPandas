function ConvertTo-PSDataFrame {
    <#
    .SYNOPSIS
    Creates a PSPandas data frame from pipeline objects or column vectors.

    .DESCRIPTION
    Ordinary PowerShell objects, dictionaries, and existing PSPandas frames are
    supported. An explicit column list can define an empty or stable schema.
    Column-oriented data can be supplied explicitly as a dictionary whose keys
    are column names and whose equally sized values are vectors.
    A file path uses the typed Import-FlatFile reader from PSFlatFile; no
    untyped Import-Csv fallback is used.

    .PARAMETER InputObject
    Ordinary objects, dictionaries, or existing PSPandas DataFrames collected
    from the pipeline into the new frame.

    .PARAMETER ColumnData
    Dictionary whose keys are column names and whose values are equally sized
    arrays, enumerable collections, or PSPandas column objects. Ordered
    dictionaries preserve declared column order. Scalars are not broadcast.

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

    .EXAMPLE
    ConvertTo-PSDataFrame -ColumnData ([ordered]@{
        age   = 17, 19, 21
        score = 12, 10, 11
        group = 'test', 'test', 'control'
    })

    .OUTPUTS
    PSPandas.DataFrame
    #>
    [CmdletBinding(DefaultParameterSetName = 'InputObject')]
    param(
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'InputObject')][AllowNull()][object]$InputObject,
        [Parameter(Mandatory, ParameterSetName = 'ColumnData')][System.Collections.IDictionary]$ColumnData,
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Path')][string]$Path,
        [Parameter(ParameterSetName = 'Path')][AllowNull()][object]$Schema,
        [Parameter(ParameterSetName = 'Path')][ValidateRange(1, 1000000)][int]$SampleSize = 100,
        [Parameter(ParameterSetName = 'Path')][ValidateSet('Auto', 'Present', 'None')][string]$HeaderMode = 'Auto',
        [Parameter(ParameterSetName = 'Path')][ValidateSet('Header', 'Generic')][string]$NameMode = 'Header',
        [Parameter(ParameterSetName = 'InputObject')]
        [Parameter(ParameterSetName = 'Path')]
        [string[]]$Columns
    )
    begin { $items = [System.Collections.Generic.List[object]]::new() }
    process {
        if ($PSCmdlet.ParameterSetName -ne 'InputObject') {
            return
        }
        if (Test-PSPandasDataFrame -Value $InputObject) {
            foreach ($row in @($InputObject.Rows)) { [void]$items.Add($row) }
        } else {
            [void]$items.Add($InputObject)
        }
    }
    end {
        if ($PSCmdlet.ParameterSetName -eq 'ColumnData') {
            $shape = ConvertTo-PSPandasColumnDataShape -ColumnData $ColumnData
            New-PSPandasDataFrameObject -Rows $shape.Rows -Columns $shape.Columns
            return
        }

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

Set-Alias -Name ctdf -Value ConvertTo-PSDataFrame
