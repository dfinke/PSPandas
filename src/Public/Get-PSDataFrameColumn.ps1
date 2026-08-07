function Get-PSDataFrameColumn {
    <#
    .SYNOPSIS
    Emits the ordered column names of a PSPandas data frame.

    .PARAMETER DataFrame
    PSPandas DataFrame whose schema is inspected. The command accepts pipeline
    input.

    .EXAMPLE
    $frame | Get-PSDataFrameColumn

    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline = $true)]$DataFrame)
    process {
        Assert-PSPandasDataFrame -DataFrame $DataFrame
        foreach ($column in $DataFrame.Columns) { Write-Output $column }
    }
}
