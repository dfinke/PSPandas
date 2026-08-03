function ConvertFrom-PSDataFrame {
    <#
    .SYNOPSIS
    Emits the rows of a PSPandas data frame as ordinary PowerShell objects.

    .EXAMPLE
    $frame | ConvertFrom-PSDataFrame | Export-Csv rows.csv -NoTypeInformation
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline = $true)]$DataFrame)
    process {
        Assert-PSPandasDataFrame -DataFrame $DataFrame
        foreach ($row in @($DataFrame.Rows)) { Write-Output $row }
    }
}
