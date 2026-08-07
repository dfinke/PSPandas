function Find-PSDataFrame {
    <#
    .SYNOPSIS
    Filters rows using a PowerShell Where-Object-style scriptblock.

    .DESCRIPTION
    Evaluates the filter against each row and returns a new DataFrame with the
    original ordered schema, including when no rows match.

    .PARAMETER DataFrame
    PSPandas DataFrame to filter. The command accepts pipeline input.

    .PARAMETER FilterScript
    Predicate evaluated with each row available as $_.

    .EXAMPLE
    $frame | Find-PSDataFrame { $_.Amount -gt 100 }

    .OUTPUTS
    PSPandas.DataFrame
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
