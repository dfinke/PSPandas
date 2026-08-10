<#
.SYNOPSIS
Analyzes a synthetic login-sales data set built from CSV-shaped rows.
#>

Import-Module $PSScriptRoot\..\..\PSPandas.psd1 -Force

$df = ConvertFrom-Csv @"
Employee,Product,Payment_Method,Sales_Amount
Alice,Laptop,Card,1200
Alice,Phone,Cash,800
Bob,Laptop,Card,1100
Bob,Tablet,Card,400
Alice,Tablet,Cash,350
Bob,Phone,Card,850
Alice,Laptop,Card,1300
Bob,Tablet,Cash,450
"@ | ConvertTo-PSDataFrame

Write-Host -ForegroundColor Cyan "Original DataFrame:"
$df

Write-Host -ForegroundColor Cyan "Basic Frequency Count:"

$df | xtab Employee Product

write-Host -ForegroundColor Cyan "Frequency Count with Totals:"
$df | xtab Employee Product -Margins

write-Host -ForegroundColor Cyan "Total Sales Amount:"
$df | pivot Employee Product Sales_Amount

write-Host -ForegroundColor Cyan "Average Sales Amount:"
$df | pivot Employee Product Sales_Amount -Aggregate average
