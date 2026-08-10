<#
.SYNOPSIS
Profiles virtual-machine cost and utilization categories with Crosstab.
#>

Import-Module $PSScriptRoot\..\..\PSPandas.psd1 -Force

$dataFile = "$PSScriptRoot\data\Azure-Cost-Resource-Optimization.csv"

#$df = Import-PSDataFrame $dataFile

$df = Import-csv $dataFile | ConvertTo-PSDataFrame

write-Host -ForegroundColor Cyan "Original DataFrame:"
$df

write-Host -ForegroundColor Cyan "Catch the underutilized, high-cost sizes:"
$df | Crosstab VM_Size Avg_CPU_Group
