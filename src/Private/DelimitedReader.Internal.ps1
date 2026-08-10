function ConvertTo-PSPandasDelimitedLine {
    <#
    .SYNOPSIS
    Splits one quoted delimited record into trimmed field values.

    .DESCRIPTION
    Handles doubled quotes inside quoted fields and preserves empty fields.
    This is the private record tokenizer used by the native PSPandas reader.

    .PARAMETER Line
    Raw delimited record text.

    .PARAMETER Delimiter
    Character separating fields.

    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Line,
        [Parameter(Mandatory)][char]$Delimiter
    )

    $values = [System.Collections.Generic.List[string]]::new()
    $builder = [System.Text.StringBuilder]::new()
    $inQuotes = $false

    for ($index = 0; $index -lt $Line.Length; $index++) {
        $character = $Line[$index]
        if ($character -eq '"') {
            if ($inQuotes -and $index + 1 -lt $Line.Length -and $Line[$index + 1] -eq '"') {
                [void]$builder.Append('"')
                $index++
            } else {
                $inQuotes = -not $inQuotes
            }
        } elseif ($character -eq $Delimiter -and -not $inQuotes) {
            [void]$values.Add($builder.ToString().Trim())
            [void]$builder.Clear()
        } else {
            [void]$builder.Append($character)
        }
    }

    if ($inQuotes) {
        throw [System.FormatException]::new(
            "Delimited record has an unterminated quoted field: '$Line'."
        )
    }

    [void]$values.Add($builder.ToString().Trim())
    $values.ToArray()
}

function Get-PSPandasNativeDelimiter {
    <#
    .SYNOPSIS
    Infers the delimiter used by sampled text records.

    .DESCRIPTION
    Compares comma, pipe, semicolon, and tab candidates by the consistency and
    width of their parsed rows. Comma is the deterministic fallback for a
    one-column file.

    .PARAMETER Lines
    Nonempty sampled records.

    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Lines)

    $candidates = @(',', '|', ';', "`t")
    $results = [System.Collections.Generic.List[object]]::new()
    for ($priority = 0; $priority -lt $candidates.Count; $priority++) {
        $candidate = [char]$candidates[$priority]
        $counts = @(
            foreach ($line in $Lines) {
                @((ConvertTo-PSPandasDelimitedLine -Line $line -Delimiter $candidate)).Count
            }
        )
        if ($counts.Count -eq 0) { continue }
        $mostCommon = @(
            $counts |
                Group-Object |
                Sort-Object `
                    @{ Expression = 'Count'; Descending = $true },
                    @{ Expression = { [int]$_.Name }; Descending = $true }
        )[0]
        if ([int]$mostCommon.Name -gt 1) {
            [void]$results.Add([pscustomobject]@{
                Delimiter   = [string]$candidate
                Consistency = [int]$mostCommon.Count
                Columns     = [int]$mostCommon.Name
                Priority    = $priority
            })
        }
    }

    if ($results.Count -eq 0) { return ',' }
    ([array]($results | Sort-Object @{ Expression = 'Consistency'; Descending = $true }, @{ Expression = 'Columns'; Descending = $true }, @{ Expression = 'Priority'; Descending = $false }))[0].Delimiter
}

function Get-PSPandasNativeTypeInference {
    <#
    .SYNOPSIS
    Infers the native type of one delimited column.

    .DESCRIPTION
    Tests exact date formats first, then Boolean, Int32, Decimal, and Double.
    Blank values are ignored for inference. A heterogeneous nonempty column is
    safely treated as String.

    .PARAMETER Values
    Sampled text values for one column.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Values)

    $nonEmpty = @($Values | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($nonEmpty.Count -eq 0) {
        return [pscustomobject][ordered]@{ Type = 'String'; Format = $null; DateOnly = $false; Scale = $null }
    }

    $culture = [Globalization.CultureInfo]::InvariantCulture
    $dateStyles = [Globalization.DateTimeStyles]::AllowWhiteSpaces
    $dateFormats = @(
        @{ Format = 'yyyy-MM-ddTHH:mm:ss.FFFFFFFK'; DateOnly = $false }
        @{ Format = 'yyyy-MM-ddTHH:mm:ssK'; DateOnly = $false }
        @{ Format = 'yyyy-MM-dd HH:mm:ss'; DateOnly = $false }
        @{ Format = 'yyyyMMddHHmmss'; DateOnly = $false }
        @{ Format = 'yyyyMMddHHmm'; DateOnly = $false }
        @{ Format = 'yyyy-MM-dd'; DateOnly = $true }
        @{ Format = 'yyyy/MM/dd'; DateOnly = $true }
        @{ Format = 'MM/dd/yyyy'; DateOnly = $true }
        @{ Format = 'M/d/yyyy'; DateOnly = $true }
        @{ Format = 'yyyyMMdd'; DateOnly = $true }
    )
    foreach ($dateFormat in $dateFormats) {
        $allDates = $true
        foreach ($value in $nonEmpty) {
            $parsed = [datetime]::MinValue
            if (-not [datetime]::TryParseExact($value, $dateFormat.Format, $culture, $dateStyles, [ref]$parsed)) {
                $allDates = $false
                break
            }
        }
        if ($allDates) {
            return [pscustomobject][ordered]@{ Type = 'DateTime'; Format = $dateFormat.Format; DateOnly = $dateFormat.DateOnly; Scale = $null }
        }
    }

    $allBoolean = $true
    foreach ($value in $nonEmpty) {
        if ($value -notmatch '^(?i:true|false)$') { $allBoolean = $false; break }
    }
    if ($allBoolean) {
        return [pscustomobject][ordered]@{ Type = 'Boolean'; Format = $null; DateOnly = $false; Scale = $null }
    }

    $allIntegers = $true
    foreach ($value in $nonEmpty) {
        $parsed = 0
        if (-not [int]::TryParse($value, [Globalization.NumberStyles]::Integer, $culture, [ref]$parsed)) { $allIntegers = $false; break }
    }
    if ($allIntegers) {
        return [pscustomobject][ordered]@{ Type = 'Int32'; Format = $null; DateOnly = $false; Scale = $null }
    }

    $allDecimals = $true
    foreach ($value in $nonEmpty) {
        $parsed = [decimal]0
        if (-not [decimal]::TryParse($value, [Globalization.NumberStyles]::Number, $culture, [ref]$parsed)) { $allDecimals = $false; break }
    }
    if ($allDecimals) {
        return [pscustomobject][ordered]@{ Type = 'Decimal'; Format = $null; DateOnly = $false; Scale = $null }
    }

    $allDoubles = $true
    $doubleStyle = [Globalization.NumberStyles]::Float -bor [Globalization.NumberStyles]::AllowThousands
    foreach ($value in $nonEmpty) {
        $parsed = [double]0
        if (-not [double]::TryParse($value, $doubleStyle, $culture, [ref]$parsed)) { $allDoubles = $false; break }
    }
    if ($allDoubles) {
        return [pscustomobject][ordered]@{ Type = 'Double'; Format = $null; DateOnly = $false; Scale = $null }
    }

    [pscustomobject][ordered]@{ Type = 'String'; Format = $null; DateOnly = $false; Scale = $null }
}

function Resolve-PSPandasNativeColumnNames {
    <#
    .SYNOPSIS
    Repairs inferred delimited-file column names.

    .DESCRIPTION
    Uses header values when requested, otherwise P1 through Pn. Blank,
    duplicate, and schema-control characters are repaired deterministically.

    .PARAMETER HeaderValues
    Header tokens, or an empty array when no header is present.

    .PARAMETER ColumnCount
    Number of columns in the sampled records.

    .PARAMETER UseHeaderNames
    Whether header tokens should become property names.

    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][AllowEmptyCollection()][object[]]$HeaderValues,
        [Parameter(Mandatory)][ValidateRange(1, 10000)][int]$ColumnCount,
        [Parameter(Mandatory)][bool]$UseHeaderNames
    )

    $used = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $names = [System.Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt $ColumnCount; $index++) {
        $generic = "P$($index + 1)"
        $source = if ($null -ne $HeaderValues -and $index -lt $HeaderValues.Count) { [string]$HeaderValues[$index] } else { '' }
        if (-not $UseHeaderNames -or [string]::IsNullOrWhiteSpace($source)) {
            $name = $generic
        } else {
            $name = [regex]::Replace($source.Trim(), '[:,|;\t\r\n]', '_')
            if ($name -eq '_' -or [string]::IsNullOrWhiteSpace($name)) { $name = $generic }
            if ($name -match '^\d+(?:\.\d+|[iI])$') { $name = "P_$name" }
        }
        $base = $name
        $suffix = 2
        while (-not $used.Add($name)) { $name = "${base}_$suffix"; $suffix++ }
        [void]$names.Add($name)
    }
    $names.ToArray()
}

function ConvertTo-PSPandasNativeFieldDefinition {
    <#
    .SYNOPSIS
    Converts one native delimited schema field definition.

    .DESCRIPTION
    Supports simple type names, PSFlatFile-compatible modifiers, exact date
    formats, and dictionary definitions containing Type, Format, and Scale.
    Fixed-width Start/Length definitions are rejected by the delimited reader.

    .PARAMETER Name
    Output property name.

    .PARAMETER Definition
    Type modifier or dictionary definition.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name,[AllowNull()]$Definition)

    $typeValue = $null; $format = $null; $scale = $null
    if ($Definition -is [System.Collections.IDictionary]) {
        foreach ($fixed in @('Start', 'Length')) { if ($Definition.Contains($fixed)) { throw "Native PSPandas delimited reader does not support fixed-width Schema definitions containing '$fixed'." } }
        if ($Definition.Contains('Type')) { $typeValue = [string]$Definition['Type'] }
        if ($Definition.Contains('Format')) { $format = [string]$Definition['Format'] }
        if ($Definition.Contains('Scale')) { $scale = [int]$Definition['Scale'] }
    } elseif ($null -ne $Definition) {
        $typeValue = [string]$Definition
    }

    $type = 'String'; $dateOnly = $false
    $modifier = if ([string]::IsNullOrWhiteSpace($typeValue)) { 'String' } else { $typeValue.Trim() }
    switch -Regex ($modifier) {
        '^(?i:string|text)$' { $type = 'String'; break }
        '^(?i:int|integer|int32|i)$' { $type = 'Int32'; break }
        '^(?i:decimal|number)$' { $type = 'Decimal'; break }
        '^(?i:double|float)$' { $type = 'Double'; break }
        '^(?i:bool|boolean)$' { $type = 'Boolean'; break }
        '^(?i:date|dateonly|d)$' { $type = 'DateTime'; $dateOnly = $true; break }
        '^(?i:datetime|dt)$' { $type = 'DateTime'; break }
        '^\d+\.\d+$' { $type = 'Decimal'; $scale = [int]$modifier.Split('.')[1]; break }
        default {
            $type = 'DateTime'
            $format = $modifier
            $dateOnly = $modifier -notmatch '(?i)(H|h|m|s|f|K|t)'
        }
    }

    if ($null -ne $scale -and ($type -ne 'Decimal' -or $scale -lt 0 -or $scale -gt 28)) {
        throw "Schema field '$Name' has an invalid Decimal Scale."
    }
    [pscustomobject][ordered]@{ Name = $Name; Index = 0; Skip = $false; Type = $type; Format = $format; DateOnly = $dateOnly; Scale = $scale }
}

function ConvertTo-PSPandasNativeDelimitedSchema {
    <#
    .SYNOPSIS
    Converts a delimited Schema parameter into native field metadata.

    .DESCRIPTION
    Accepts a PSFlatFile-style single-line schema or an ordered dictionary of
    property names and type definitions. Fixed-width schemas are rejected with
    an actionable message because this reader owns delimited files only.

    .PARAMETER Schema
    Schema string or dictionary.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Schema)

    $fields = [System.Collections.Generic.List[object]]::new()
    $delimiter = $null
    if ($Schema -is [string]) {
        if ($Schema.Contains("`n") -or $Schema -match '(?m)^\s*@\d+') { throw 'Native PSPandas delimited reader does not support fixed-width Schema strings.' }
        $schemaText = $Schema.Trim()
        foreach ($candidate in @(',', '|', ';', "`t")) {
            if ($schemaText.Contains($candidate)) { $delimiter = [char]$candidate; break }
        }
        if ($null -eq $delimiter) { $delimiter = ' ' }
        $tokens = if ($delimiter -eq ' ') { @([regex]::Split($schemaText, '\s+')) } else { @(ConvertTo-PSPandasDelimitedLine -Line $schemaText -Delimiter $delimiter) }
        $index = 0
        foreach ($token in $tokens) {
            $text = ([string]$token).Trim()
            if ([string]::IsNullOrWhiteSpace($text)) { throw 'Native delimited Schema contains an empty field definition.' }
            $name = $text; $modifier = $null
            $colon = $text.IndexOf(':')
            if ($colon -ge 0) { $name = $text.Substring(0, $colon).Trim(); $modifier = $text.Substring($colon + 1).Trim() }
            if ([string]::IsNullOrWhiteSpace($name)) { throw 'Native delimited Schema field names cannot be empty.' }
            $skip = $name -eq '_' -or $modifier -match '^(?i:skip)$'
            $fieldName = if ($skip) { "__skip_$($index + 1)" } else { $name }
            $field = ConvertTo-PSPandasNativeFieldDefinition -Name $fieldName -Definition $modifier
            $field.Index = $index; $field.Skip = $skip
            [void]$fields.Add($field); $index++
        }
    } elseif ($Schema -is [System.Collections.IDictionary]) {
        if ($Schema.Count -eq 0) { throw 'Native delimited Schema cannot be empty.' }
        $index = 0
        foreach ($entry in $Schema.GetEnumerator()) {
            $name = [string]$entry.Key
            if ([string]::IsNullOrWhiteSpace($name)) { throw 'Native delimited Schema field names cannot be empty.' }
            $field = ConvertTo-PSPandasNativeFieldDefinition -Name $name -Definition $entry.Value
            $field.Index = $index; [void]$fields.Add($field); $index++
        }
    } else {
        throw 'Schema must be a delimited schema string or an IDictionary of property type definitions.'
    }

    if (@($fields | Where-Object { -not $_.Skip }).Count -eq 0) { throw 'Native delimited Schema must define at least one output column.' }
    [pscustomobject][ordered]@{ Delimiter = $delimiter; Fields = [object[]]$fields.ToArray() }
}

function ConvertTo-PSPandasNativeCell {
    <#
    .SYNOPSIS
    Converts one native reader field value to its inferred or declared type.

    .PARAMETER Text
    Trimmed source field text.

    .PARAMETER Field
    Native field metadata.

    .PARAMETER LineNumber
    One-based source line number used in errors.

    .OUTPUTS
    System.Object
    #>
    [CmdletBinding()]
    param([AllowEmptyString()][string]$Text,[Parameter(Mandatory)]$Field,[Parameter(Mandatory)][int]$LineNumber)

    $valueText = if ($null -eq $Text) { '' } else { $Text.Trim() }
    if ($Field.Type -eq 'String') { return $valueText }
    if ($valueText.Length -eq 0) { return $null }
    $culture = [Globalization.CultureInfo]::InvariantCulture
    try {
        switch ($Field.Type) {
            'Int32' {
                $value = 0
                if (-not [int]::TryParse($valueText, [Globalization.NumberStyles]::Integer, $culture, [ref]$value)) { throw 'Invalid Int32 value.' }
                return $value
            }
            'Decimal' {
                $value = [decimal]0
                if (-not [decimal]::TryParse($valueText, [Globalization.NumberStyles]::Number, $culture, [ref]$value)) { throw 'Invalid Decimal value.' }
                if ($null -ne $Field.Scale -and [int]$Field.Scale -gt 0 -and $valueText -match '^[+-]?\d+$') {
                    for ($index = 0; $index -lt [int]$Field.Scale; $index++) { $value /= 10 }
                }
                return $value
            }
            'Double' {
                $value = [double]0; $style = [Globalization.NumberStyles]::Float -bor [Globalization.NumberStyles]::AllowThousands
                if (-not [double]::TryParse($valueText, $style, $culture, [ref]$value)) { throw 'Invalid Double value.' }
                return $value
            }
            'Boolean' {
                switch -Regex ($valueText) {
                    '^(?i:true|yes|y|1)$' { return $true }
                    '^(?i:false|no|n|0)$' { return $false }
                    default { throw 'Invalid Boolean value.' }
                }
            }
            'DateTime' {
                $value = [datetime]::MinValue; $styles = [Globalization.DateTimeStyles]::AllowWhiteSpaces
                $parsed = if ([string]::IsNullOrWhiteSpace($Field.Format)) { [datetime]::TryParse($valueText, $culture, $styles, [ref]$value) } else { [datetime]::TryParseExact($valueText, [string]$Field.Format, $culture, $styles, [ref]$value) }
                if (-not $parsed) { throw 'Invalid DateTime value.' }
                if ($Field.DateOnly) {
                    if ($value.TimeOfDay -ne [timespan]::Zero) { throw 'The value contains a time component, but the field is DateOnly.' }
                    return [System.DateOnly]::new($value.Year, $value.Month, $value.Day)
                }
                return $value
            }
        }
    } catch {
        throw [System.IO.InvalidDataException]::new("Cannot convert field '$($Field.Name)' value '$valueText' on line $LineNumber to $($Field.Type): $($_.Exception.Message)", $_.Exception)
    }
}

function Import-PSPandasNativeDelimitedFile {
    <#
    .SYNOPSIS
    Imports a typed delimited file without external reader modules.

    .DESCRIPTION
    Reads common comma, pipe, semicolon, and tab-delimited text files with
    quoted fields, inferred or declared schemas, header/name handling, and
    native PowerShell conversion to String, Int32, Decimal, Double, Boolean,
    DateOnly, or DateTime values.

    .PARAMETER Path
    Existing delimited file path.

    .PARAMETER Schema
    Optional delimited schema string or type dictionary.

    .PARAMETER SampleSize
    Maximum number of nonempty records used for inference.

    .PARAMETER HeaderMode
    Auto, Present, or None header handling.

    .PARAMETER NameMode
    Header or Generic inferred property names.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$Path,
        [AllowNull()]$Schema,
        [ValidateRange(1, 1000000)][int]$SampleSize = 100,
        [ValidateSet('Auto', 'Present', 'None')][string]$HeaderMode = 'Auto',
        [ValidateSet('Header', 'Generic')][string]$NameMode = 'Header'
    )

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $supportedExtensions = @('.csv', '.tsv', '.tab', '.psv', '.txt', '.dat', '.del', '.log')
    if ($extension -and $extension -notin $supportedExtensions) {
        throw "Unsupported delimited file extension '$extension' for '$Path'. Supported extensions are CSV, TSV, PSV, TAB, TXT, DAT, DEL, and LOG."
    }

    try { $allLines = @(Get-Content -LiteralPath $Path -ErrorAction Stop | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }
    catch { throw "Native PSPandas delimited reader could not read '$Path': $($_.Exception.Message)" }
    if ($allLines.Count -eq 0) { throw [System.IO.InvalidDataException]::new("File '$Path' does not contain any nonempty records.") }

    $sampleLines = @($allLines | Select-Object -First $SampleSize)
    $schemaInfo = $null
    if ($PSBoundParameters.ContainsKey('Schema')) {
        $schemaInfo = ConvertTo-PSPandasNativeDelimitedSchema -Schema $Schema
        $delimiter = $schemaInfo.Delimiter
        if ($delimiter -eq ' ') { $delimiter = $null }
        if ($null -eq $delimiter) { $delimiter = Get-PSPandasNativeDelimiter -Lines $sampleLines }
    } else {
        $delimiter = Get-PSPandasNativeDelimiter -Lines $sampleLines
    }

    $parseLine = {
        param([string]$Line)
        if ($null -eq $delimiter -or $delimiter -eq ' ') {
            $trimmed = $Line.Trim()
            if ($trimmed.Length -eq 0) { return @() }
            return @([regex]::Split($trimmed, '\s+'))
        }
        return @(ConvertTo-PSPandasDelimitedLine -Line $Line -Delimiter ([char]$delimiter))
    }
    $sampleRows = @(foreach ($line in $sampleLines) { ,([object[]](& $parseLine $line)) })
    $allRows = @(foreach ($line in $allLines) { ,([object[]](& $parseLine $line)) })
    $columnCount = 0
    foreach ($row in $sampleRows) { $columnCount = [Math]::Max($columnCount, @($row).Count) }
    foreach ($row in $allRows) { $columnCount = [Math]::Max($columnCount, @($row).Count) }
    if ($columnCount -eq 0) { throw [System.IO.InvalidDataException]::new("File '$Path' does not contain any fields.") }

    $headerPresent = $HeaderMode -eq 'Present'
    $fields = [System.Collections.Generic.List[object]]::new()
    if ($null -ne $schemaInfo) {
        foreach ($field in $schemaInfo.Fields) { [void]$fields.Add($field) }
        if ($HeaderMode -eq 'Auto' -and @($allRows[0]).Count -gt 0) {
            $matches = $true
            foreach ($field in $fields | Where-Object { -not $_.Skip }) {
                if ($field.Index -ge @($allRows[0]).Count -or -not [string]::Equals([string]$allRows[0][$field.Index], [string]$field.Name, [StringComparison]::OrdinalIgnoreCase)) { $matches = $false; break }
            }
            $headerPresent = $matches
        }
    } else {
        $headerPresent = $HeaderMode -eq 'Present'
        if ($HeaderMode -eq 'Auto' -and $sampleRows.Count -gt 1) {
            for ($columnIndex = 0; $columnIndex -lt $columnCount; $columnIndex++) {
                $remaining = [System.Collections.Generic.List[string]]::new()
                $allValues = [System.Collections.Generic.List[string]]::new()
                for ($rowIndex = 0; $rowIndex -lt $sampleRows.Count; $rowIndex++) {
                    $row = @($sampleRows[$rowIndex]); $text = if ($columnIndex -lt $row.Count) { [string]$row[$columnIndex] } else { '' }
                    [void]$allValues.Add($text); if ($rowIndex -gt 0) { [void]$remaining.Add($text) }
                }
                $remainingType = Get-PSPandasNativeTypeInference -Values $remaining.ToArray()
                $allType = Get-PSPandasNativeTypeInference -Values $allValues.ToArray()
                if ($remainingType.Type -ne 'String' -and $allType.Type -eq 'String') { $headerPresent = $true; break }
            }
        }
        $headerValues = if ($headerPresent) { @($sampleRows[0]) } else { @() }
        $names = Resolve-PSPandasNativeColumnNames -HeaderValues $headerValues -ColumnCount $columnCount -UseHeaderNames ($headerPresent -and $NameMode -eq 'Header')
        $firstData = if ($headerPresent) { 1 } else { 0 }
        for ($columnIndex = 0; $columnIndex -lt $columnCount; $columnIndex++) {
            $values = [System.Collections.Generic.List[string]]::new()
            for ($rowIndex = $firstData; $rowIndex -lt $sampleRows.Count; $rowIndex++) { $row = @($sampleRows[$rowIndex]); [void]$values.Add($(if ($columnIndex -lt $row.Count) { [string]$row[$columnIndex] } else { '' })) }
            $inferred = Get-PSPandasNativeTypeInference -Values $values.ToArray()
            $field = [pscustomobject][ordered]@{ Name = $names[$columnIndex]; Index = $columnIndex; Skip = $false; Type = $inferred.Type; Format = $inferred.Format; DateOnly = $inferred.DateOnly; Scale = $inferred.Scale }
            [void]$fields.Add($field)
        }
    }

    $startRow = if ($headerPresent) { 1 } else { 0 }
    $outputRows = [System.Collections.Generic.List[object]]::new()
    for ($rowIndex = $startRow; $rowIndex -lt $allRows.Count; $rowIndex++) {
        $tokens = @($allRows[$rowIndex]); $ordered = [ordered]@{}
        foreach ($field in $fields | Where-Object { -not $_.Skip }) {
            $text = if ($field.Index -lt $tokens.Count) { [string]$tokens[$field.Index] } else { '' }
            $ordered[$field.Name] = ConvertTo-PSPandasNativeCell -Text $text -Field $field -LineNumber ($rowIndex + 1)
        }
        [void]$outputRows.Add([pscustomobject]$ordered)
    }
    $outputRows.ToArray()
}
