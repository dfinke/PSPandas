function Get-PSDataFrameTail {
    <#
    .SYNOPSIS
    Emits the last rows of a PSPandas data frame.

    .DESCRIPTION
    Emits ordinary row objects in their original order. If Count exceeds the
    frame size, all rows are emitted; Count 0 emits no rows.

    .PARAMETER DataFrame
    PSPandas DataFrame to inspect. The command accepts pipeline input.

    .PARAMETER Count
    Maximum number of rows to emit. The default is 5.

    .EXAMPLE
    $frame | Get-PSDataFrameTail -Count 10

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
        if ($Count -eq 0) {
            return
        }

        @($DataFrame.Rows) | Select-Object -Last $Count
    }
}
