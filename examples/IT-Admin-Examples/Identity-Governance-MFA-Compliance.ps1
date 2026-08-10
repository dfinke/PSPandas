<#
.SYNOPSIS
Analyzes synthetic identity-governance MFA status by risk level.
#>

Import-Module $PSScriptRoot\..\..\PSPandas.psd1 -Force

$dataFile = "$PSScriptRoot\data\Identity-Governance-MFA-Compliance.csv"

$df = Import-Csv $dataFile | ConvertTo-PSDataFrame

Write-Host -ForegroundColor Cyan "Original DataFrame:"
$df

Write-Host -ForegroundColor Cyan "See your exact security gaps:"
$df | Crosstab Risk_Level MFA_Status -Margins
