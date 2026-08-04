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

    The friendly -Count, -Sum, -Average, -Min, and -Max parameters accept one
    or more property names. They generate names such as Count_OrderId and
    Sum_Amount. The advanced -Aggregate form remains available for custom names
    and scriptblocks.

    .EXAMPLE
    $sales | Measure-PSDataFrame -By Region -Aggregate @{
        Orders = @{ Function = 'Count' }
        Revenue = @{ Property = 'Amount'; Function = 'Sum' }
    }

    .EXAMPLE
    $orders | Summarize -By State -Count OrderId -Sum Amount, Tax
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true)]$DataFrame,
        [string[]]$By = @(),
        [System.Collections.IDictionary]$Aggregate,
        [string[]]$Count = @(),
        [string[]]$Sum = @(),
        [string[]]$Average = @(),
        [string[]]$Min = @(),
        [string[]]$Max = @()
    )
    process {
        Assert-PSPandasDataFrame -DataFrame $DataFrame
        if ($By.Count -gt 0) { Assert-PSPandasColumns -DataFrame $DataFrame -Columns $By }

        $aggregateSpecs = [ordered]@{}
        $friendlyOperations = [ordered]@{
            Count   = $Count
            Sum     = $Sum
            Average = $Average
            Min     = $Min
            Max     = $Max
        }
        foreach ($operation in $friendlyOperations.Keys) {
            foreach ($propertyName in @($friendlyOperations[$operation])) {
                if ([string]::IsNullOrWhiteSpace($propertyName)) {
                    throw "The -$operation parameter cannot contain an empty property name."
                }
                $outputName = "{0}_{1}" -f $operation, $propertyName
                if ($aggregateSpecs.Contains($outputName)) {
                    throw "Duplicate friendly aggregate output name '$outputName'."
                }
                $aggregateSpecs[$outputName] = [ordered]@{
                    Property = $propertyName
                    Function = $operation
                }
            }
        }

        if ($null -ne $Aggregate) {
            foreach ($name in $Aggregate.Keys) {
                $outputName = [string]$name
                if ($aggregateSpecs.Contains($outputName)) {
                    throw "Aggregate output name '$outputName' collides with a friendly aggregate output."
                }
                $aggregateSpecs[$outputName] = $Aggregate[$name]
            }
        }

        if ($aggregateSpecs.Count -eq 0) {
            throw 'Specify -Aggregate or at least one friendly aggregate parameter such as -Count, -Sum, -Average, -Min, or -Max.'
        }

        foreach ($name in $aggregateSpecs.Keys) {
            $propertyName = Get-PSPandasAggregatePropertyName -OutputName ([string]$name) -Specification $aggregateSpecs[$name]
            if ($propertyName) {
                Assert-PSPandasColumns -DataFrame $DataFrame -Columns @($propertyName)
            }
        }
        $outputColumns = @($By) + @($aggregateSpecs.Keys | ForEach-Object { [string]$_ })

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
            foreach ($name in $aggregateSpecs.Keys) {
                $ordered[[string]$name] = Invoke-PSPandasAggregate -Rows @($group.Rows) -Specification $aggregateSpecs[$name] -OutputName ([string]$name)
            }
            [pscustomobject]$ordered
        }
        New-PSPandasDataFrameObject -Rows @($rows) -Columns $outputColumns
    }
}
Set-Alias -Name Summarize-PSDataFrame -Value Measure-PSDataFrame
Set-Alias -Name Summarize-PSDF -Value Measure-PSDataFrame
Set-Alias -Name Summarize -Value Measure-PSDataFrame
