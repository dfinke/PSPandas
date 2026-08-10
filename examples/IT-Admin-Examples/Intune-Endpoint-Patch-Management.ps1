<#
.SYNOPSIS
Calculates synthetic endpoint patch compliance by operating-system version.
#>

Import-Module $PSScriptRoot\..\..\PSPandas.psd1 -Force

$dataFile = "$PSScriptRoot\data\Intune-Endpoint-Patch-Management.csv"

#$df = Import-PSDataFrame $dataFile

$df = Import-csv $dataFile | ConvertTo-PSDataFrame

write-Host -ForegroundColor Cyan "Original DataFrame:"
$df

write-Host -ForegroundColor Cyan "find the exact percentage of out-of-date machines per OS version:"

$df | Crosstab OS_Version Patch_Status -Normalize Index
""
$df | Crosstab OS_Version Patch_Status -Normalize Index -Percent
