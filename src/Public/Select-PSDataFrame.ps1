function Select-PSDataFrame {
    <#
    .SYNOPSIS
    Selects and reorders columns while preserving row order.

    .EXAMPLE
    $frame | Select-PSDataFrame -Property Name, Amount
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true)]$DataFrame,
        [Parameter(Mandatory, Position = 0)][string[]]$Property
    )
    process {
        Assert-PSPandasDataFrame -DataFrame $DataFrame
        Assert-PSPandasColumns -DataFrame $DataFrame -Columns $Property
        $rows = foreach ($row in @($DataFrame.Rows)) {
            ConvertTo-PSPandasRow -InputObject $row -Columns $Property
        }
        New-PSPandasDataFrameObject -Rows @($rows) -Columns $Property
    }
}
Set-Alias -Name Select-PSDF -Value Select-PSDataFrame
