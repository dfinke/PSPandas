function Group-PSDataFrame {
    <#
    .SYNOPSIS
    Groups rows by one or more columns.

    .OUTPUTS
    Each output object has Key, Rows, Count, and DataFrame properties.
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
