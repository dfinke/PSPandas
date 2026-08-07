function Join-PSDataFrame {
    <#
    .SYNOPSIS
    Joins two PSPandas data frames on one or more key columns.

    .DESCRIPTION
    Inner, left, right, and full joins are supported. Non-key name collisions
    receive _left and _right suffixes by default.

    .PARAMETER Left
    Left-hand PSPandas data frame.

    .PARAMETER Right
    Right-hand PSPandas data frame.

    .PARAMETER On
    One or more key columns shared by both data frames.

    .PARAMETER JoinType
    Join type: Inner, Left, Right, or Full. The default is Inner.

    .PARAMETER LeftSuffix
    Suffix for a non-key column collision from the left frame.

    .PARAMETER RightSuffix
    Suffix for a non-key column collision from the right frame.

    .EXAMPLE
    $orders = @(
        [pscustomobject]@{ OrderId = 1001; CustomerId = 'C01'; Amount = 20 }
        [pscustomobject]@{ OrderId = 1002; CustomerId = 'C02'; Amount = 15 }
    ) | ConvertTo-PSDataFrame

    $customers = @(
        [pscustomobject]@{ CustomerId = 'C01'; Customer = 'Ada' }
        [pscustomobject]@{ CustomerId = 'C02'; Customer = 'Bea' }
    ) | ConvertTo-PSDataFrame

    Join-PSDataFrame -Left $orders -Right $customers -On CustomerId -JoinType Left

    .EXAMPLE
    Join-PSDataFrame -Left $orders -Right $customers -On CustomerId |
        ConvertFrom-PSDataFrame | Format-Table

    .OUTPUTS
    PSPandas.DataFrame
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]$Left,
        [Parameter(Mandatory, Position = 1)]$Right,
        [Parameter(Mandatory)][string[]]$On,
        [ValidateSet('Inner', 'Left', 'Right', 'Full')][string]$JoinType = 'Inner',
        [string]$LeftSuffix = '_left',
        [string]$RightSuffix = '_right'
    )

    Assert-PSPandasDataFrame -DataFrame $Left -ParameterName 'Left'
    Assert-PSPandasDataFrame -DataFrame $Right -ParameterName 'Right'
    Assert-PSPandasColumns -DataFrame $Left -Columns $On
    Assert-PSPandasColumns -DataFrame $Right -Columns $On

    $leftOutput = foreach ($column in $Left.Columns) {
        if ($column -notin $On -and $Right.Columns -contains $column) { "$column$LeftSuffix" } else { $column }
    }
    $rightOutput = foreach ($column in $Right.Columns) {
        if ($column -in $On) { continue }
        if ($Left.Columns -contains $column) { "$column$RightSuffix" } else { $column }
    }
    $outputColumns = @($leftOutput) + @($rightOutput)

    $rightIndex = @{}
    foreach ($rightRow in @($Right.Rows)) {
        $values = @($On | ForEach-Object { Get-PSPandasPropertyValue -InputObject $rightRow -Name $_ })
        $key = Get-PSPandasGroupKey -Values $values
        if (-not $rightIndex.ContainsKey($key)) {
            $rightIndex[$key] = [System.Collections.Generic.List[object]]::new()
        }
        [void]$rightIndex[$key].Add($rightRow)
    }

    $matchedRight = [System.Collections.Generic.HashSet[string]]::new()
    $joinedRows = [System.Collections.Generic.List[object]]::new()
    foreach ($leftRow in @($Left.Rows)) {
        $values = @($On | ForEach-Object { Get-PSPandasPropertyValue -InputObject $leftRow -Name $_ })
        $key = Get-PSPandasGroupKey -Values $values
        $matches = if ($rightIndex.ContainsKey($key)) { @($rightIndex[$key].ToArray()) } else { @() }
        if (@($matches).Count -gt 0) {
            [void]$matchedRight.Add($key)
            foreach ($rightRow in $matches) {
                $ordered = [ordered]@{}
                for ($i = 0; $i -lt $Left.Columns.Count; $i++) {
                    $ordered[$leftOutput[$i]] = Get-PSPandasPropertyValue -InputObject $leftRow -Name $Left.Columns[$i]
                }
                foreach ($column in $Right.Columns) {
                    if ($column -in $On) { continue }
                    $outputName = if ($Left.Columns -contains $column) { "$column$RightSuffix" } else { $column }
                    $ordered[$outputName] = Get-PSPandasPropertyValue -InputObject $rightRow -Name $column
                }
                [void]$joinedRows.Add([pscustomobject]$ordered)
            }
        } elseif ($JoinType -in @('Left', 'Full')) {
            $ordered = [ordered]@{}
            for ($i = 0; $i -lt $Left.Columns.Count; $i++) {
                $ordered[$leftOutput[$i]] = Get-PSPandasPropertyValue -InputObject $leftRow -Name $Left.Columns[$i]
            }
            foreach ($outputName in $rightOutput) { $ordered[$outputName] = $null }
            [void]$joinedRows.Add([pscustomobject]$ordered)
        }
    }

    if ($JoinType -in @('Right', 'Full')) {
        foreach ($rightRow in @($Right.Rows)) {
            $values = @($On | ForEach-Object { Get-PSPandasPropertyValue -InputObject $rightRow -Name $_ })
            $key = Get-PSPandasGroupKey -Values $values
            if (-not $matchedRight.Contains($key)) {
                $ordered = [ordered]@{}
                foreach ($outputName in $leftOutput) { $ordered[$outputName] = $null }
                foreach ($column in $Right.Columns) {
                    if ($column -in $On) { continue }
                    $outputName = if ($Left.Columns -contains $column) { "$column$RightSuffix" } else { $column }
                    $ordered[$outputName] = Get-PSPandasPropertyValue -InputObject $rightRow -Name $column
                }
                [void]$joinedRows.Add([pscustomobject]$ordered)
            }
        }
    }

    New-PSPandasDataFrameObject -Rows $joinedRows.ToArray() -Columns $outputColumns
}
Set-Alias -Name Join-PSDF -Value Join-PSDataFrame
