<#
.SYNOPSIS
Builds a synthetic access-log frame and compares authentication outcomes.
#>

Import-Module $PSScriptRoot\..\..\PSPandas.psd1 -Force

$df = ConvertFrom-Csv @"
User_ID,Department,Location,App_Name,Auth_Result
user_106,Engineering,US-East,Office 365,MFA Prompt
user_119,Finance,AP-South,Azure Portal,Failure
user_114,Sales,EU-West,GitHub,Success
user_110,Sales,US-East,Office 365,Success
user_107,Engineering,US-East,Azure Portal,Success
user_106,Engineering,BR-East,Office 365,MFA Prompt
user_118,Sales,EU-West,Azure Portal,Success
user_110,Engineering,US-East,GitHub,Success
user_110,Engineering,US-East,Office 365,Success
user_103,Finance,US-East,Office 365,Success
user_107,Engineering,US-East,Salesforce,Success
user_102,Engineering,EU-West,GitHub,Success
user_101,Sales,EU-West,Office 365,Success
user_111,Engineering,AP-South,Office 365,Success
user_105,Finance,US-East,Office 365,Success
user_106,Engineering,US-East,Office 365,MFA Prompt
user_119,Finance,AP-South,Azure Portal,Failure
user_114,Sales,EU-West,GitHub,Success
user_110,Sales,US-East,Office 365,Success
user_107,Engineering,US-East,Azure Portal,Success
user_106,Engineering,BR-East,Office 365,MFA Prompt
user_118,Sales,EU-West,Azure Portal,Success
user_110,Engineering,US-East,GitHub,Success
user_110,Engineering,US-East,Office 365,Success
user_103,Finance,US-East,Office 365,Success
user_107,Engineering,US-East,Salesforce,Success
user_102,Engineering,EU-West,GitHub,Success
user_101,Sales,EU-West,Office 365,Success
user_111,Engineering,AP-South,Office 365,Success
user_105,Finance,US-East,Office 365,Success
"@ | ConvertTo-PSDataFrame

Write-Host -ForegroundColor Cyan "Original DataFrame:"
$df

Write-Host -ForegroundColor Cyan "Crosstab of Location and Auth_Result with Totals:"
$df | Crosstab Location Auth_Result -Margins

Write-Host -ForegroundColor Cyan "Crosstab of Department and App_Name with Totals:"
$df | Crosstab department App_Name -Margins

Write-Host -ForegroundColor Cyan "Crosstab of Department and Auth_Result with Totals:"
$df | Crosstab department Auth_Result -Margins

Write-Host -ForegroundColor Cyan "Crosstab of Department and Auth_Result with Normalized Index:"
$df | Crosstab department Auth_Result -Normalize Index

Write-Host -ForegroundColor Cyan "Crosstab of Department and Auth_Result with Normalized Columns:"
$df | Crosstab department Auth_Result -Normalize Columns

Write-Host -ForegroundColor Cyan "Crosstab of Department and Auth_Result with Normalized All:"
$df | Crosstab department Auth_Result -Normalize All
