function Import-PSDataFrame {
    <#
    .SYNOPSIS
    Imports a typed delimited file or Excel worksheet as a PSPandas data frame.

    .DESCRIPTION
    Reads common CSV, TSV, PSV, and other supported delimited files through
    PSPandas' native typed reader. XLSX and XLSM workbooks use Import-Excel
    from the optional ImportExcel module. When no worksheet name is supplied,
    the first worksheet is imported. Use -AsWorkbook to return all worksheets
    in a workbook object with tab-completable sheet properties. HTTP and
    HTTPS URI input is downloaded and processed through the same readers.
    Import-PSDataFrame is the file-oriented entry point; use
    ConvertTo-PSDataFrame for ordinary pipeline objects.

    .PARAMETER Path
    Path to the file to import.

    .PARAMETER Uri
    Absolute HTTP or HTTPS URI to download and import.

    .PARAMETER TimeoutSec
    Maximum number of seconds allowed for an HTTP or HTTPS download. The
    default is 30 seconds.

    .PARAMETER Schema
    Optional schema for native delimited-file type conversion.

    .PARAMETER SampleSize
    Maximum number of nonempty file lines used by native type inference.

    .PARAMETER HeaderMode
    Header handling used by native delimited-file inference.

    .PARAMETER NameMode
    Inferred property-name mode used by the native delimited reader.

    .PARAMETER WorksheetName
    Worksheet to read from an XLSX or XLSM workbook. When omitted, the first
    worksheet is imported. This parameter is not valid for flat-file input.

    .PARAMETER AsWorkbook
    Returns a workbook object containing one PSPandas data frame per worksheet.
    This parameter is valid only for XLSX and XLSM input and cannot be combined
    with WorksheetName.

    .EXAMPLE
    Import-PSDataFrame .\orders.csv

    .EXAMPLE
    Import-PSDataFrame .\orders.csv | Describe

    .EXAMPLE
    Import-PSDataFrame -Uri 'https://example.com/orders.csv' | Describe

    .EXAMPLE
    Import-PSDataFrame .\sales.xlsx -WorksheetName Orders | Describe

    .EXAMPLE
    $book = Import-PSDataFrame .\yearlySales.xlsx -AsWorkbook
    # Press Ctrl+Space after '$book.' to complete worksheet names.
    $book.January | Summarize -By Region -Sum Amount

    .OUTPUTS
    PSPandas.DataFrame or PSPandas.Workbook when AsWorkbook is used.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Path')][string]$Path,
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Uri')][uri]$Uri,
        [Parameter(ParameterSetName = 'Uri')][ValidateRange(1, 600)][int]$TimeoutSec = 30,
        [AllowNull()][object]$Schema,
        [ValidateRange(1, 1000000)][int]$SampleSize = 100,
        [ValidateSet('Auto', 'Present', 'None')][string]$HeaderMode = 'Auto',
        [ValidateSet('Header', 'Generic')][string]$NameMode = 'Header',
        [ValidateNotNullOrEmpty()][string]$WorksheetName,
        [switch]$AsWorkbook
    )

    if ($PSCmdlet.ParameterSetName -eq 'Uri') {
        $temporaryPath = Save-PSPandasUriToTemporaryFile -Uri $Uri -TimeoutSec $TimeoutSec
        try {
            $localParameters = @{ Path = $temporaryPath }
            foreach ($parameterName in @('Schema', 'SampleSize', 'HeaderMode', 'NameMode', 'WorksheetName', 'AsWorkbook')) {
                if ($PSBoundParameters.ContainsKey($parameterName)) { $localParameters[$parameterName] = $PSBoundParameters[$parameterName] }
            }
            return Import-PSDataFrame @localParameters
        } finally {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Path '$Path' does not exist or is not a file."
    }

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $displayExtension = if ([string]::IsNullOrWhiteSpace($extension)) { '<none>' } else { $extension }
    $excelExtensions = @('.xlsx', '.xlsm')

    if ($extension -in $excelExtensions) {
        Write-PSPandasProgress -Enabled -Activity 'PSPandas import' -Status 'Reading Excel worksheet metadata' -PercentComplete 10 -Id 3
        foreach ($flatFileParameter in @('Schema', 'SampleSize', 'HeaderMode', 'NameMode')) {
            if ($PSBoundParameters.ContainsKey($flatFileParameter)) {
                throw "Parameter '-$flatFileParameter' is for flat-file input and cannot be used with Excel file extension '$displayExtension'."
            }
        }
        if ($AsWorkbook -and $PSBoundParameters.ContainsKey('WorksheetName')) {
            throw "Parameters '-AsWorkbook' and '-WorksheetName' cannot be combined for Excel input. Use -AsWorkbook for all worksheets or -WorksheetName for one worksheet."
        }
        $excelReader = Get-Command -Name Import-Excel -ErrorAction SilentlyContinue
        if ($null -eq $excelReader) {
            throw "Cannot read '$Path' as an Excel PSPandas data source because Import-Excel was not found. Install or import the ImportExcel module before using .xlsx or .xlsm input."
        }

        if ($AsWorkbook) {
            $sheetInfoReader = Get-Command -Name Get-ExcelSheetInfo -ErrorAction SilentlyContinue
            if ($null -eq $sheetInfoReader) {
                throw "Cannot inspect Excel worksheets for '$Path' because Get-ExcelSheetInfo was not found. Import the ImportExcel module before using -AsWorkbook."
            }

            try {
                $sheetInfo = @( & $sheetInfoReader -Path $Path | Sort-Object -Property @{ Expression = { [int]$_.Index } })
            } catch {
                throw "Excel worksheet inspection failed for '$Path': $($_.Exception.Message)"
            }
            if ($sheetInfo.Count -eq 0) {
                throw "Excel workbook '$Path' contains no worksheets."
            }

            $worksheetFrames = [System.Collections.Generic.List[object]]::new()
            foreach ($sheet in $sheetInfo) {
                $sheetName = [string]$sheet.Name
                $sheetRows = @(Import-PSPandasExcelRows -Path $Path -Reader $excelReader -WorksheetName $sheetName)
                $sheetFrame = New-PSPandasDataFrameObject -Rows $sheetRows
                [void]$worksheetFrames.Add([pscustomobject][ordered]@{
                    Name      = $sheetName
                    DataFrame = $sheetFrame
                })
                $sheetPercent = [int](10 + (85 * ($worksheetFrames.Count / [Math]::Max(1, $sheetInfo.Count))))
                Write-PSPandasProgress -Enabled -Activity 'PSPandas import' -Status "Read worksheet $($worksheetFrames.Count) of $($sheetInfo.Count)" -PercentComplete $sheetPercent -Id 3
            }

            $resolvedPath = (Resolve-Path -LiteralPath $Path).ProviderPath
            Write-PSPandasProgress -Enabled -Activity 'PSPandas import' -Status 'Workbook import complete' -PercentComplete 100 -Id 3 -Completed
            return New-PSPandasWorkbookObject -Path $resolvedPath -Worksheets $worksheetFrames.ToArray()
        }

        $excelRows = @(Import-PSPandasExcelRows -Path $Path -Reader $excelReader -WorksheetName $WorksheetName)
        Write-PSPandasProgress -Enabled -Activity 'PSPandas import' -Status 'Excel import complete' -PercentComplete 100 -Id 3 -Completed
        return New-PSPandasDataFrameObject -Rows $excelRows
    }

    if ($AsWorkbook) {
        throw "Parameter '-AsWorkbook' is only valid for Excel files with extension '.xlsx' or '.xlsm'; supplied path has extension '$displayExtension'."
    }
    if ($PSBoundParameters.ContainsKey('WorksheetName')) {
        throw "Parameter '-WorksheetName' is only valid for Excel files with extension '.xlsx' or '.xlsm'; supplied path has extension '$displayExtension'."
    }

    $readerParameters = @{
        Path       = $Path
        SampleSize = $SampleSize
        HeaderMode = $HeaderMode
        NameMode   = $NameMode
    }
    if ($PSBoundParameters.ContainsKey('Schema')) {
        $readerParameters.Schema = $Schema
    }
    $typedRows = @(Import-PSPandasTypedFile @readerParameters)
    New-PSPandasDataFrameObject -Rows $typedRows
}
