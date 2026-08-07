function ConvertFrom-PSDataFrame {
    <#
    .SYNOPSIS
    Emits the rows of a PSPandas data frame as ordinary PowerShell objects.

    .DESCRIPTION
    Unwraps DataFrame rows for commands that expect one ordinary object at a
    time, including PowerShell exporters and external modules.

    .PARAMETER DataFrame
    PSPandas DataFrame whose rows are emitted. The command accepts pipeline
    input.

    .EXAMPLE
    $frame | ConvertFrom-PSDataFrame | Export-Csv rows.csv -NoTypeInformation

    .OUTPUTS
    System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline = $true)]$DataFrame)
    process {
        Assert-PSPandasDataFrame -DataFrame $DataFrame
        foreach ($row in @($DataFrame.Rows)) { Write-Output $row }
    }
}
