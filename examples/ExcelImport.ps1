<#
.SYNOPSIS
Demonstrates importing a single Excel worksheet as a DataFrame.

.DESCRIPTION
Uses ImportExcel with PSPandas file import and shows the resulting typed frame.

.EXAMPLE
& ./examples/ExcelImport.ps1
#>

Import-Module ImportExcel -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$path = Join-Path ([System.IO.Path]::GetTempPath()) "pspandas-excel-example-$PID.xlsx"
try {
    $sourceRows = @(
        [pscustomobject][ordered]@{ Region = 'East'; OrderId = 1001; Amount = 20.50; OrderDate = [datetime]'2026-01-05' }
        [pscustomobject][ordered]@{ Region = 'West'; OrderId = 1002; Amount = 15.25; OrderDate = [datetime]'2026-02-12' }
        [pscustomobject][ordered]@{ Region = 'East'; OrderId = 1003; Amount = 45.00; OrderDate = [datetime]'2026-03-18' }
    )
    $sourceRows | Export-Excel -Path $path -WorksheetName Orders -AutoSize

    $orders = Import-PSDataFrame $path
    $orders
    $orders | Describe -AsRows | Format-Table Column, Type, RowCount, Minimum, Maximum
} finally {
    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
}
