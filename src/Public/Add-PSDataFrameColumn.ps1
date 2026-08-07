function Add-PSDataFrameColumn {
    <#
    .SYNOPSIS
    Adds a calculated column using a PowerShell scriptblock.

    .DESCRIPTION
    The scriptblock receives each row through $_ and as its first argument.

    .PARAMETER DataFrame
    PSPandas DataFrame to transform. The command accepts pipeline input.

    .PARAMETER Name
    Name of the calculated column. New columns are appended to the schema.

    .PARAMETER Expression
    Scriptblock evaluated once for each row.

    .PARAMETER Force
    Replaces an existing column with the same name and moves it to the end of
    the schema.

    .EXAMPLE
    $frame | Add-PSDataFrameColumn -Name Total -Expression { $_.Price * $_.Quantity }

    .OUTPUTS
    PSPandas.DataFrame
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true)]$DataFrame,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory, Position = 0)][scriptblock]$Expression,
        [switch]$Force
    )
    process {
        Assert-PSPandasDataFrame -DataFrame $DataFrame
        if ($DataFrame.Columns -contains $Name -and -not $Force) {
            throw "Column '$Name' already exists. Use -Force to replace it."
        }
        $columns = [System.Collections.Generic.List[string]]::new()
        foreach ($column in $DataFrame.Columns) {
            if ($column -ne $Name) { [void]$columns.Add($column) }
        }
        [void]$columns.Add($Name)
        $rows = foreach ($row in @($DataFrame.Rows)) {
            $ordered = [ordered]@{}
            foreach ($column in $columns) {
                if ($column -eq $Name) {
                    if ($null -ne $Expression.Ast.ParamBlock -and $Expression.Ast.ParamBlock.Parameters.Count -gt 0) {
                        $result = @($row | ForEach-Object { & $Expression $_ })
                    } else {
                        $result = @($row | ForEach-Object -Process $Expression)
                    }
                    $ordered[$column] = if ($result.Count -le 1) { $result | Select-Object -First 1 } else { $result }
                } else {
                    $ordered[$column] = Get-PSPandasPropertyValue -InputObject $row -Name $column
                }
            }
            [pscustomobject]$ordered
        }
        New-PSPandasDataFrameObject -Rows @($rows) -Columns $columns.ToArray()
    }
}
Set-Alias -Name Add-PSDFColumn -Value Add-PSDataFrameColumn
