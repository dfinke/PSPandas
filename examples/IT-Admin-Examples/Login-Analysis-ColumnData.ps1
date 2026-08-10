<#
.SYNOPSIS
Analyzes a synthetic login-sales data set built from column vectors.
#>

Import-Module $PSScriptRoot\..\..\PSPandas.psd1 -Force

$df = ConvertTo-PSDataFrame -ColumnData ([ordered]@{
        "Employee"       = @("Alice", "Alice", "Bob", "Bob", "Alice", "Bob", "Alice", "Bob")
        "Product"        = @("Laptop", "Phone", "Laptop", "Tablet", "Tablet", "Phone", "Laptop", "Tablet")
        "Payment_Method" = @("Card", "Cash", "Card", "Card", "Cash", "Card", "Card", "Cash")
        "Sales_Amount"   = @(1200, 800, 1100, 400, 350, 850, 1300, 450)
    })


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
