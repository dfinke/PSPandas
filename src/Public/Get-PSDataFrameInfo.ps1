function Get-PSDataFrameInfo {
    <#
    .SYNOPSIS
    Returns basic schema and size information for a PSPandas data frame.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline = $true)]$DataFrame)
    process {
        Assert-PSPandasDataFrame -DataFrame $DataFrame
        [pscustomobject][ordered]@{
            Columns     = [string[]]$DataFrame.Columns
            ColumnCount = @($DataFrame.Columns).Count
            RowCount    = @($DataFrame.Rows).Count
        }
    }
}
