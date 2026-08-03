function Get-PSDataFrameHead {
    <#
    .SYNOPSIS
    Emits the first rows of a PSPandas data frame.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true)]$DataFrame,
        [ValidateRange(0, 2147483647)][int]$Count = 5
    )
    process {
        Assert-PSPandasDataFrame -DataFrame $DataFrame
        @($DataFrame.Rows) | Select-Object -First $Count
    }
}
