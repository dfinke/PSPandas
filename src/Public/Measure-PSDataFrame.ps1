function Measure-PSDataFrame {
    <#
    .SYNOPSIS
    Aggregates rows globally or by grouping columns.

    .DESCRIPTION
    Aggregate values are scriptblocks receiving the group rows, strings naming a
    property (summed by default), or hashtables such as
    @{ Property = 'Amount'; Function = 'Sum' }. For non-count hashtable
    specifications that omit Property, the aggregate output name is used as
    the source property name.

    .EXAMPLE
    $sales | Measure-PSDataFrame -By Region -Aggregate @{
        Orders = @{ Function = 'Count' }
        Revenue = @{ Property = 'Amount'; Function = 'Sum' }
    }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true)]$DataFrame,
        [string[]]$By = @(),
        [Parameter(Mandatory)][System.Collections.IDictionary]$Aggregate
    )
    process {
        Assert-PSPandasDataFrame -DataFrame $DataFrame
        if ($By.Count -gt 0) { Assert-PSPandasColumns -DataFrame $DataFrame -Columns $By }
        foreach ($name in $Aggregate.Keys) {
            $propertyName = Get-PSPandasAggregatePropertyName -OutputName ([string]$name) -Specification $Aggregate[$name]
            if ($propertyName) {
                Assert-PSPandasColumns -DataFrame $DataFrame -Columns @($propertyName)
            }
        }
        $outputColumns = @($By) + @($Aggregate.Keys | ForEach-Object { [string]$_ })

        if (@($DataFrame.Rows).Count -eq 0) {
            New-PSPandasDataFrameObject -Rows @() -Columns $outputColumns
            return
        }

        $groups = if ($By.Count -gt 0) {
            @(Group-PSDataFrame -DataFrame $DataFrame -By $By)
        } else {
            @([pscustomobject][ordered]@{ Rows = [object[]]$DataFrame.Rows })
        }

        $rows = foreach ($group in $groups) {
            $ordered = [ordered]@{}
            if ($By.Count -gt 0) {
                $key = $group.Key
                if ($By.Count -eq 1) {
                    $ordered[$By[0]] = $key
                } else {
                    foreach ($column in $By) {
                        $ordered[$column] = Get-PSPandasPropertyValue -InputObject $key -Name $column
                    }
                }
            }
            foreach ($name in $Aggregate.Keys) {
                $ordered[[string]$name] = Invoke-PSPandasAggregate -Rows @($group.Rows) -Specification $Aggregate[$name] -OutputName ([string]$name)
            }
            [pscustomobject]$ordered
        }
        New-PSPandasDataFrameObject -Rows @($rows) -Columns $outputColumns
    }
}
Set-Alias -Name Summarize-PSDataFrame -Value Measure-PSDataFrame
Set-Alias -Name Summarize-PSDF -Value Measure-PSDataFrame
