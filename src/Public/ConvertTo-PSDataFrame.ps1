function ConvertTo-PSDataFrame {
    <#
    .SYNOPSIS
    Creates a PSPandas data frame from pipeline objects.

    .DESCRIPTION
    Ordinary PowerShell objects, dictionaries, and existing PSPandas frames are
    supported. An explicit column list can define an empty or stable schema.

    .EXAMPLE
    Import-Csv .\orders.csv | ConvertTo-PSDataFrame
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)][AllowNull()][object]$InputObject,
        [string[]]$Columns
    )
    begin { $items = [System.Collections.Generic.List[object]]::new() }
    process {
        if (Test-PSPandasDataFrame -Value $InputObject) {
            foreach ($row in @($InputObject.Rows)) { [void]$items.Add($row) }
        } else {
            [void]$items.Add($InputObject)
        }
    }
    end { New-PSPandasDataFrameObject -Rows $items.ToArray() -Columns $Columns }
}
