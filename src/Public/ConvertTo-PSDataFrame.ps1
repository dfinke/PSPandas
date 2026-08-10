function ConvertTo-PSDataFrame {
    <#
    .SYNOPSIS
    Creates a PSPandas data frame from pipeline objects or column vectors.

    .DESCRIPTION
    Ordinary PowerShell objects, dictionaries, and existing PSPandas frames are
    supported. An explicit column list can define an empty or stable schema.
    Column-oriented data can be supplied explicitly as a dictionary whose keys
    are column names and whose equally sized values are vectors.
    A file path or HTTP/HTTPS URI uses PSPandas' native typed delimited reader;
    no external PSFlatFile dependency or untyped Import-Csv fallback is required.

    .PARAMETER InputObject
    Ordinary objects, dictionaries, or existing PSPandas DataFrames collected
    from the pipeline into the new frame.

    .PARAMETER ColumnData
    Dictionary whose keys are column names and whose values are equally sized
    arrays, enumerable collections, or PSPandas column objects. Ordered
    dictionaries preserve declared column order. Scalars are not broadcast.

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

    .PARAMETER Columns
    Optional ordered schema. It defines empty frames and normalizes input rows
    to a stable set and order of properties.

    .EXAMPLE
    Import-Csv .\orders.csv | ConvertTo-PSDataFrame

    .EXAMPLE
    ConvertTo-PSDataFrame .\orders.csv

    .EXAMPLE
    ConvertTo-PSDataFrame -Uri 'https://example.com/orders.csv'

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
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Uri')][uri]$Uri,
        [Parameter(ParameterSetName = 'Uri')][ValidateRange(1, 600)][int]$TimeoutSec = 30,
        [Parameter(ParameterSetName = 'Path')][Parameter(ParameterSetName = 'Uri')][AllowNull()][object]$Schema,
        [Parameter(ParameterSetName = 'Path')][Parameter(ParameterSetName = 'Uri')][ValidateRange(1, 1000000)][int]$SampleSize = 100,
        [Parameter(ParameterSetName = 'Path')][Parameter(ParameterSetName = 'Uri')][ValidateSet('Auto', 'Present', 'None')][string]$HeaderMode = 'Auto',
        [Parameter(ParameterSetName = 'Path')][Parameter(ParameterSetName = 'Uri')][ValidateSet('Header', 'Generic')][string]$NameMode = 'Header',
        [Parameter(ParameterSetName = 'InputObject')]
        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'Uri')]
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

        if ($PSCmdlet.ParameterSetName -in @('Path', 'Uri')) {
            $temporaryPath = $null
            $sourcePath = $Path
            if ($PSCmdlet.ParameterSetName -eq 'Uri') {
                $temporaryPath = Save-PSPandasUriToTemporaryFile -Uri $Uri -TimeoutSec $TimeoutSec
                $sourcePath = $temporaryPath
            }
            $readerParameters = @{
                Path       = $sourcePath
                SampleSize = $SampleSize
                HeaderMode = $HeaderMode
                NameMode   = $NameMode
            }
            try {
                if ($PSBoundParameters.ContainsKey('Schema')) {
                    $readerParameters.Schema = $Schema
                }
                $typedRows = @(Import-PSPandasTypedFile @readerParameters)
                New-PSPandasDataFrameObject -Rows $typedRows -Columns $Columns
                return
            } finally {
                if ($null -ne $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue }
            }
        }

        New-PSPandasDataFrameObject -Rows $items.ToArray() -Columns $Columns
    }
}

Set-Alias -Name ctdf -Value ConvertTo-PSDataFrame
