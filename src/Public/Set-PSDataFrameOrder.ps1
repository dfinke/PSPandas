function Set-PSDataFrameOrder {
    <#
    .SYNOPSIS
    Sorts rows by one or more existing columns.
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
