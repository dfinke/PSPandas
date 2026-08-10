<#
.SYNOPSIS
Demonstrates typed flat-file import into a PSPandas DataFrame.

.DESCRIPTION
Loads PSPandas, imports a local delimited fixture with its native typed reader,
and inspects the frame.

.EXAMPLE
& ./examples/Import.ps1
#>

Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$path = Join-Path ([System.IO.Path]::GetTempPath()) 'pspandas-import-example.csv'
try {
    @(
        'Region,OrderId,Amount,OrderDate'
        'East,1001,20.50,2026-01-05'
        'West,1002,15.25,2026-02-12'
        'East,1003,45.00,2026-03-18'
    ) | Set-Content -LiteralPath $path

    $orders = Import-PSDataFrame $path
    $orders
    $orders | Describe -AsRows | Format-Table Column, Type, RowCount, Minimum, Maximum
} finally {
    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
}
