Import-Module ImportExcel -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$path = Join-Path ([System.IO.Path]::GetTempPath()) "pspandas-workbook-example-$PID.xlsx"
try {
    @(
        [pscustomobject][ordered]@{ Region = 'East'; Amount = 20.50 }
        [pscustomobject][ordered]@{ Region = 'West'; Amount = 15.25 }
    ) | Export-Excel -Path $path -WorksheetName January -AutoSize

    @(
        [pscustomobject][ordered]@{ Region = 'East'; Amount = 45.00 }
        [pscustomobject][ordered]@{ Region = 'North'; Amount = 30.00 }
    ) | Export-Excel -Path $path -WorksheetName February -AutoSize

    $book = Import-PSDataFrame $path -AsWorkbook
    $book
    $book.Worksheets.Names
    $book.January | Summarize -By Region -Sum Amount | ConvertFrom-PSDataFrame | Format-Table
    $book.Worksheets['February'] | Describe -AsRows | Format-Table Column, Type, RowCount, Minimum, Maximum
} finally {
    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
}
