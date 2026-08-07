function Get-PSDataFrameHead {
    <#
    .SYNOPSIS
    Emits the first rows of a PSPandas data frame.

    .PARAMETER DataFrame
    PSPandas DataFrame to inspect. The command accepts pipeline input.

    .PARAMETER Count
    Maximum number of rows to emit. The default is 5.

    .EXAMPLE
    $frame | Get-PSDataFrameHead -Count 10

    .OUTPUTS
    System.Management.Automation.PSCustomObject
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
