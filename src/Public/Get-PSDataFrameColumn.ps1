function Get-PSDataFrameColumn {
    <#
    .SYNOPSIS
    Emits the ordered column names of a PSPandas data frame.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline = $true)]$DataFrame)
    process {
        Assert-PSPandasDataFrame -DataFrame $DataFrame
        foreach ($column in $DataFrame.Columns) { Write-Output $column }
    }
}
