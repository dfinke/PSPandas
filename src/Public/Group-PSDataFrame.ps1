function Group-PSDataFrame {
    <#
    .SYNOPSIS
    Groups rows by one or more columns.

    .DESCRIPTION
    Preserves first-seen group order. Each emitted group includes the public
    key, ordinary rows, row count, and a DataFrame containing the group rows.

    .PARAMETER DataFrame
    PSPandas DataFrame to group. The command accepts pipeline input.

    .PARAMETER By
    One or more existing columns that form the group key.

    .EXAMPLE
    $frame | Group-PSDataFrame -By Region, State

    .OUTPUTS
    System.Management.Automation.PSCustomObject. Each output object has Key,
    Rows, Count, and DataFrame properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true)]$DataFrame,
        [Parameter(Mandatory, Position = 0)][string[]]$By
    )
    process {
        Assert-PSPandasDataFrame -DataFrame $DataFrame
        Assert-PSPandasColumns -DataFrame $DataFrame -Columns $By
        $groups = [ordered]@{}
        foreach ($row in @($DataFrame.Rows)) {
            $values = @($By | ForEach-Object { Get-PSPandasPropertyValue -InputObject $row -Name $_ })
            $key = Get-PSPandasGroupKey -Values $values
            if (-not $groups.Contains($key)) {
                $groups[$key] = [System.Collections.Generic.List[object]]::new()
            }
            [void]$groups[$key].Add($row)
        }

        foreach ($groupRows in $groups.Values) {
            $rowsArray = [object[]]$groupRows.ToArray()
            [pscustomobject][ordered]@{
                Key       = Get-PSPandasGroupKeyObject -Row $rowsArray[0] -By $By
                Rows      = $rowsArray
                Count     = $rowsArray.Count
                DataFrame = New-PSPandasDataFrameObject -Rows $rowsArray -Columns $DataFrame.Columns
            }
        }
    }
}
Set-Alias -Name Group-PSDF -Value Group-PSDataFrame
