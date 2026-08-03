function Find-PSDataFrame {
    <#
    .SYNOPSIS
    Filters rows using a PowerShell Where-Object-style scriptblock.

    .EXAMPLE
    $frame | Find-PSDataFrame { $_.Amount -gt 100 }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true)]$DataFrame,
        [Parameter(Mandatory, Position = 0)][scriptblock]$FilterScript
    )
    process {
        Assert-PSPandasDataFrame -DataFrame $DataFrame
        Assert-PSPandasColumns -DataFrame $DataFrame -Columns @($DataFrame.Columns)
        $rows = @($DataFrame.Rows | Where-Object -FilterScript $FilterScript)
        New-PSPandasDataFrameObject -Rows $rows -Columns $DataFrame.Columns
    }
}
Set-Alias -Name Where-PSDataFrame -Value Find-PSDataFrame
Set-Alias -Name Where-PSDF -Value Find-PSDataFrame
