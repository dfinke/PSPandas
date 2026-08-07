function Import-PSDataFrame {
    <#
    .SYNOPSIS
    Imports a typed flat file as a PSPandas data frame.

    .DESCRIPTION
    Reads a CSV, TSV, or other supported flat file through Import-FlatFile
    from PSFlatFile, then returns a PSPandas data frame. Import-PSDataFrame
    is the file-oriented entry point; use ConvertTo-PSDataFrame for ordinary
    pipeline objects.

    .PARAMETER Path
    Path to the file to import.

    .PARAMETER Schema
    Optional schema passed to Import-FlatFile.

    .PARAMETER SampleSize
    Maximum number of nonempty file lines used by Import-FlatFile inference.

    .PARAMETER HeaderMode
    Header handling passed to Import-FlatFile.

    .PARAMETER NameMode
    Inferred property-name mode passed to Import-FlatFile.

    .EXAMPLE
    Import-PSDataFrame .\orders.csv

    .EXAMPLE
    Import-PSDataFrame .\orders.csv | Describe
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$Path,
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

    $typedRows = @(Import-PSPandasTypedFile @readerParameters)
    New-PSPandasDataFrameObject -Rows $typedRows
}
