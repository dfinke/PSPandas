function Set-PSDataFrameOrder {
    <#
    .SYNOPSIS
    Sorts rows by one or more existing columns.

    .PARAMETER DataFrame
    PSPandas DataFrame to sort. The command accepts pipeline input.

    .PARAMETER Property
    One or more sort columns, evaluated in the supplied order.

    .PARAMETER Descending
    Sorts all requested properties in descending order.

    .EXAMPLE
    $frame | Set-PSDataFrameOrder -Property Region, Amount -Descending

    .OUTPUTS
    PSPandas.DataFrame
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true)]$DataFrame,
        [Parameter(Mandatory, Position = 0)][string[]]$Property,
        [switch]$Descending
    )
    process {
        Assert-PSPandasDataFrame -DataFrame $DataFrame
        Assert-PSPandasColumns -DataFrame $DataFrame -Columns $Property
        $rows = @($DataFrame.Rows | Sort-Object -Property $Property -Descending:$Descending)
        New-PSPandasDataFrameObject -Rows $rows -Columns $DataFrame.Columns
    }
}
Set-Alias -Name Sort-PSDataFrame -Value Set-PSDataFrameOrder
Set-Alias -Name Sort-PSDF -Value Set-PSDataFrameOrder
