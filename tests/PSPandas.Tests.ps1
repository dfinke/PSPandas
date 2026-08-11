<#
.SYNOPSIS
Validates PSPandas construction, profiling, transformations, joins, and edges.

.DESCRIPTION
Runs the primary Pester coverage for the public DataFrame API, typed import,
workbook access, display behavior, column objects, and compatibility aliases.
#>

$describeAlias = Get-Alias -Name Describe -ErrorAction SilentlyContinue
if ($describeAlias -and $describeAlias.Source -eq 'PSPandas') {
    # Pester's Describe DSL must win during discovery when PSPandas is already imported.
    Remove-Item -Path Alias:Describe -Force
}

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\PSPandas.psd1'
    Import-Module $modulePath -Force

    $testRows = @(
        [pscustomobject][ordered]@{ Region = 'East'; Product = 'A'; Quantity = 2; Amount = 20 }
        [pscustomobject][ordered]@{ Region = 'West'; Product = 'B'; Quantity = 1; Amount = 15 }
        [pscustomobject][ordered]@{ Region = 'East'; Product = 'C'; Quantity = 3; Amount = 45 }
    )
    $frame = $testRows | ConvertTo-PSDataFrame
}

Describe 'PSPandas construction and inspection' {
    It 'constructs an ordered frame from pipeline objects' {
        $frame.PSTypeNames | Should -Contain 'PSPandas.DataFrame'
        ($frame.Columns -join ',') | Should -Be 'Region,Product,Quantity,Amount'
        @($frame.Rows).Count | Should -Be 3
        $frame.Count | Should -Be 3
    }

    It 'constructs an ordered frame from column vectors' {
        $age = 17, 19, 21, 37, 18, 19, 47, 18, 19
        $score = 12, 10, 11, 15, 16, 14, 25, 21, 29
        $rt = 3.552, 1.624, 6.431, 7.132, 2.925, 4.662, 3.634, 3.635, 5.234
        $group = 'test', 'test', 'test', 'test', 'test', 'control', 'control', 'control', 'control'

        $columnFrame = ConvertTo-PSDataFrame -ColumnData ([ordered]@{
            age   = $age
            score = $score
            rt    = $rt
            group = $group
        })

        ($columnFrame.Columns -join ',') | Should -Be 'age,score,rt,group'
        $columnFrame.Count | Should -Be 9
        $columnFrame.Rows[0].age | Should -Be 17
        $columnFrame.Rows[5].group | Should -Be 'control'
        $columnFrame.Rows[0].age | Should -BeOfType [int]
        $columnFrame.Rows[0].rt | Should -BeOfType [double]
        $columnFrame['score'].Sum() | Should -Be 153
    }

    It 'handles typed, nullable, empty, and existing column vectors' {
        $nullable = [object[]](1, $null, 3)
        $typed = ConvertTo-PSDataFrame -ColumnData ([ordered]@{
            Id     = [int[]](10, 20, 30)
            Amount = [decimal[]](1.25, 2.50, 3.75)
            Maybe  = $nullable
        })

        $typed.Rows[0].Id | Should -BeOfType [int]
        $typed.Rows[0].Amount | Should -BeOfType [decimal]
        $typed.Rows[1].Maybe | Should -BeNullOrEmpty

        $fromColumns = ConvertTo-PSDataFrame -ColumnData ([ordered]@{
            IdCopy     = $typed['Id']
            AmountCopy = $typed['Amount']
        })
        $fromColumns.Count | Should -Be 3
        $fromColumns.Rows[2].AmountCopy | Should -Be 3.75

        $empty = ConvertTo-PSDataFrame -ColumnData ([ordered]@{
            Id   = [int[]]@()
            Name = [string[]]@()
        })
        ($empty.Columns -join ',') | Should -Be 'Id,Name'
        $empty.Count | Should -Be 0
    }

    It 'rejects invalid column-vector construction clearly without changing row dictionaries' {
        { ConvertTo-PSDataFrame -ColumnData ([ordered]@{ A = 1, 2, 3; B = 1, 2 }) } |
            Should -Throw "*ColumnData vectors must have the same length*Column 'B' has 2 values*expected 3*"
        { ConvertTo-PSDataFrame -ColumnData ([ordered]@{ A = 1 }) } |
            Should -Throw "*Scalar values are not broadcast*"

        $rowDictionary = [ordered]@{ Values = 1, 2, 3 }
        $singleRow = ConvertTo-PSDataFrame -InputObject $rowDictionary
        $singleRow.Count | Should -Be 1
        @($singleRow.Rows[0].Values).Count | Should -Be 3
    }

    It 'supports explicit columns and empty frames' {
        $empty = ConvertTo-PSDataFrame -Columns Name, Amount
        ($empty.Columns -join ',') | Should -Be 'Name,Amount'
        @($empty.Rows).Count | Should -Be 0
        $empty.Count | Should -Be 0
    }

    It 'reports info, columns, and head rows' {
        $info = $frame | Get-PSDataFrameInfo
        $info.RowCount | Should -Be 3
        $info.ColumnCount | Should -Be 4
        @($frame | Get-PSDataFrameColumn) | Should -Be @('Region', 'Product', 'Quantity', 'Amount')
        @($frame | Get-PSDataFrameHead -Count 2).Count | Should -Be 2
        ($frame | Get-PSDataFrameHead -Count 1).Product | Should -Be 'A'
        @($frame | Get-PSDataFrameTail -Count 2).Count | Should -Be 2
        ($frame | Get-PSDataFrameTail -Count 1).Product | Should -Be 'C'
        @($frame | Get-PSDataFrameTail -Count 0).Count | Should -Be 0
    }

    It 'uses the row table as the default display without changing frame semantics' {
        $display = $frame | Out-String
        $display | Should -Match 'Region'
        $display | Should -Match 'Product'
        $display | Should -Not -Match 'Columns'
        $display | Should -Not -Match 'Rows'

        $empty = ConvertTo-PSDataFrame -Columns Region, Product
        $emptyDisplay = $empty | Out-String
        $emptyDisplay | Should -Match '0 rows'
        $empty.GetType().FullName | Should -Be 'PSPandas.DataFrame'
        @($empty.Rows).Count | Should -Be 0
    }

    It 'round-trips rows as ordinary PowerShell objects' {
        $rows = @($frame | ConvertFrom-PSDataFrame)
        $rows[1].Product | Should -Be 'B'
        $rows[2].Amount | Should -Be 45

        $converted = $frame | ConvertTo-PSDataFrame
        @($converted.Rows).Count | Should -Be 3
    }

    It 'exports the approved command names and compatibility aliases' {
        @(Get-Command New-PSDataFrame -Module PSPandas -ErrorAction SilentlyContinue).Count | Should -Be 0
        (Get-Command ConvertTo-PSDataFrame -Module PSPandas).CommandType | Should -Be 'Function'
        (Get-Command ctdf -Module PSPandas).CommandType | Should -Be 'Alias'
        (Get-Command ctdf -Module PSPandas).Definition | Should -Be 'ConvertTo-PSDataFrame'
        (Get-Command Import-PSDataFrame -Module PSPandas).CommandType | Should -Be 'Function'
        (Get-Command Find-PSDataFrame).CommandType | Should -Be 'Function'
        (Get-Command Set-PSDataFrameOrder).CommandType | Should -Be 'Function'
        (Get-Command Measure-PSDataFrame).CommandType | Should -Be 'Function'
        (Get-Command Where-PSDataFrame).CommandType | Should -Be 'Alias'
        (Get-Command Where-PSDataFrame).Definition | Should -Be 'Find-PSDataFrame'
        (Get-Command Sort-PSDataFrame).Definition | Should -Be 'Set-PSDataFrameOrder'
        (Get-Command Summarize-PSDataFrame).Definition | Should -Be 'Measure-PSDataFrame'
        (Get-Command Summarize).CommandType | Should -Be 'Alias'
        (Get-Command Summarize).Definition | Should -Be 'Measure-PSDataFrame'
        (Get-Command Describe -Module PSPandas).CommandType | Should -Be 'Alias'
        (Get-Command Describe -Module PSPandas).Definition | Should -Be 'Get-PSDataFrameProfile'
        foreach ($commandName in @('Import-PSDataFrame', 'ConvertTo-PSDataFrame', 'Get-PSDataFrameProfile')) {
            (Get-Command $commandName -Module PSPandas).Parameters.ContainsKey('Progress') | Should -BeFalse
            (Get-Command $commandName -Module PSPandas).Parameters.ContainsKey('ProgressAction') | Should -BeTrue
        }
        (Get-Command Get-NormalRandom -Module PSPandas).CommandType | Should -Be 'Function'
        (Get-Command Get-NormalRandom -Module PSPandas).Parameters.ContainsKey('Count') | Should -BeTrue
        (Get-Command Get-RandomInt -Module PSPandas).CommandType | Should -Be 'Function'
        (Get-Command Get-RandomInt -Module PSPandas).Parameters.ContainsKey('Minimum') | Should -BeTrue
        (Get-Command Get-RandomInt -Module PSPandas).Parameters.ContainsKey('Maximum') | Should -BeTrue
        (Get-Command Get-PSDateRange -Module PSPandas).CommandType | Should -Be 'Function'
        (Get-Command Get-PSDateRange -Module PSPandas).Parameters.ContainsKey('Frequency') | Should -BeTrue
    }
}

Describe 'Get-NormalRandom' {
    It 'generates the requested number of standard-normal doubles' {
        $values = @(Get-NormalRandom -Count 12 -Seed 42)

        $values.Count | Should -Be 12
        $values | ForEach-Object { $_.GetType().FullName | Should -Be 'System.Double' }
        $values | Where-Object { [double]::IsNaN($_) -or [double]::IsInfinity($_) } | Should -BeNullOrEmpty
    }

    It 'supports repeatable seeded sequences' {
        $first = @(Get-NormalRandom -Count 5 -Seed 42)
        $second = @(Get-NormalRandom -Count 5 -Seed 42)

        ($first -join ',') | Should -Be ($second -join ',')
    }

    It 'defaults to one value and validates count' {
        @(Get-NormalRandom -Seed 42).Count | Should -Be 1
        { Get-NormalRandom -Count 0 } | Should -Throw
    }
}

Describe 'Get-RandomInt' {
    It 'generates the requested number of Int32 values within exclusive bounds' {
        $values = @(Get-RandomInt -Count 12 -Minimum 10 -Maximum 20 -Seed 42)

        $values.Count | Should -Be 12
        $values | ForEach-Object {
            $_.GetType().FullName | Should -Be 'System.Int32'
            $_ | Should -BeGreaterOrEqual 10
            $_ | Should -BeLessThan 20
        }
    }

    It 'supports repeatable seeded sequences' {
        $first = @(Get-RandomInt -Count 5 -Minimum 1 -Maximum 100 -Seed 42)
        $second = @(Get-RandomInt -Count 5 -Minimum 1 -Maximum 100 -Seed 42)

        ($first -join ',') | Should -Be ($second -join ',')
    }

    It 'defaults to one value and validates bounds' {
        @(Get-RandomInt -Seed 42).Count | Should -Be 1
        { Get-RandomInt -Minimum 10 -Maximum 10 } | Should -Throw '*Maximum must be greater than Minimum*'
    }
}

Describe 'Get-PSDateRange' {
    It 'generates an inclusive daily DateTime range' {
        $values = @(Get-PSDateRange -Start '2024-01-01' -End '2024-01-03')

        $values.Count | Should -Be 3
        $values[0] | Should -Be ([datetime]'2024-01-01')
        $values[2] | Should -Be ([datetime]'2024-01-03')
        $values | ForEach-Object { $_.GetType().FullName | Should -Be 'System.DateTime' }
    }

    It 'supports periods, month starts, business days, and DateOnly output' {
        $months = @(Get-PSDateRange -Start '2024-01-15' -Periods 3 -Frequency MS -DateOnly)
        $businessDays = @(Get-PSDateRange -End '2024-01-05' -Periods 5 -Frequency BusinessDay)

        $months.Count | Should -Be 3
        $months[0].GetType().FullName | Should -Be 'System.DateOnly'
        $months[0] | Should -Be ([System.DateOnly]::new(2024, 1, 1))
        $months[2] | Should -Be ([System.DateOnly]::new(2024, 3, 1))
        $businessDays.Count | Should -Be 5
        $businessDays[0].DayOfWeek | Should -Be ([DayOfWeek]::Monday)
        $businessDays[4].DayOfWeek | Should -Be ([DayOfWeek]::Friday)
    }

    It 'supports endpoint exclusion and validates the two-of-three contract' {
        $values = @(Get-PSDateRange -Start '2024-01-01' -End '2024-01-03' -Inclusive Neither)

        $values.Count | Should -Be 1
        $values[0] | Should -Be ([datetime]'2024-01-02')
        { Get-PSDateRange -Start '2024-01-01' } | Should -Throw '*exactly two*'
        { Get-PSDateRange -Start '2024-01-01' -End '2024-01-03' -Periods 3 } | Should -Throw '*exactly two*'
        { Get-PSDateRange -Start '2024-01-01' -Periods 3 -Inclusive Left } | Should -Throw '*only when both*'
    }
}

Describe 'PSPandas progress behavior' {
    It 'emits automatic progress by default' {
        Mock -CommandName Write-Progress -ModuleName PSPandas
        $path = Join-Path $TestDrive 'quiet-progress.csv'
        @('Region,Units', 'East,2', 'West,3') | Set-Content -LiteralPath $path

        $default = Import-PSDataFrame -Path $path
        Assert-MockCalled Write-Progress -ModuleName PSPandas -Times 1
    }

    It 'respects ProgressPreference suppression without changing results' {
        Mock -CommandName Write-Progress -ModuleName PSPandas
        $path = Join-Path $TestDrive 'suppressed-progress.csv'
        @('Region,Units', 'East,2', 'West,3') | Set-Content -LiteralPath $path

        $module = Get-Module PSPandas
        $previousPreference = $module.SessionState.PSVariable.Get('ProgressPreference').Value
        $module.SessionState.PSVariable.Set('ProgressPreference', 'SilentlyContinue')
        try {
            $suppressed = Import-PSDataFrame -Path $path
        } finally {
            $module.SessionState.PSVariable.Set('ProgressPreference', $previousPreference)
        }
        Assert-MockCalled Write-Progress -ModuleName PSPandas -Times 0 -Exactly
        $suppressed.GetType().FullName | Should -Be 'PSPandas.DataFrame'
        @($suppressed.Rows).Count | Should -Be 2
    }

    It 'emits automatic progress for import, conversion, and profiling without changing results' {
        $script:progressCallCount = 0
        Mock -CommandName Write-Progress -ModuleName PSPandas -MockWith { $script:progressCallCount++ }
        $path = Join-Path $TestDrive 'enabled-progress.csv'
        @('Region,Units,OrderDate', 'East,2,2026-01-05', 'West,3,2026-02-12') | Set-Content -LiteralPath $path

        $imported = Import-PSDataFrame -Path $path
        $converted = ConvertTo-PSDataFrame -Path $path
        $profile = Get-PSDataFrameProfile -Path $path -AsRows

        $script:progressCallCount | Should -BeGreaterThan 0
        ($imported.Columns -join ',') | Should -Be ($converted.Columns -join ',')
        @($imported.Rows).Count | Should -Be @($converted.Rows).Count
        @($profile).Count | Should -Be 3
    }
}

Describe 'PSPandas column objects' {
    It 'supports lookup, values, and numeric scalar operations' {
        $column = $frame['Amount']
        $column.GetType().Name | Should -Be 'DataFrameColumn'
        $column.Name | Should -Be 'Amount'
        @($column.Values) | Should -Be @(20, 15, 45)
        $column.Count() | Should -Be 3
        $column.Sum() | Should -Be 80
        $column.Average() | Should -Be (80 / 3)
        $column.Min() | Should -Be 15
        $column.Max() | Should -Be 45
        $column[0] | Should -Be 20
        @($column[0..2]) | Should -Be @(20, 15, 45)
        $column[-1] | Should -Be 45
        { $column[3] } | Should -Throw '*outside the range*'
    }

    It 'ignores nulls and handles empty columns predictably' {
        $withNulls = @(
            [pscustomobject][ordered]@{ Units = [int32]1 }
            [pscustomobject][ordered]@{ Units = $null }
            [pscustomobject][ordered]@{ Units = [int32]3 }
        ) | ConvertTo-PSDataFrame
        $column = $withNulls['Units']
        @($column.Values).Count | Should -Be 3
        $column.Count() | Should -Be 2
        $column.Sum() | Should -Be 4
        $column.Average() | Should -Be 2
        $column.Min() | Should -Be 1
        $column.Max() | Should -Be 3

        $empty = ConvertTo-PSDataFrame -Columns Units
        $emptyColumn = $empty['Units']
        @($emptyColumn.Values).Count | Should -Be 0
        $emptyColumn.Count() | Should -Be 0
        $emptyColumn.Sum() | Should -Be 0
        $emptyColumn.Average() | Should -Be $null
        $emptyColumn.Min() | Should -Be $null
        $emptyColumn.Max() | Should -Be $null
    }

    It 'reports missing and incompatible column operations clearly' {
        { $frame['Missing'] } | Should -Throw '*does not exist*'
        $bad = @(
            [pscustomobject][ordered]@{ Units = [int32]1 }
            [pscustomobject][ordered]@{ Units = 'not numeric' }
        ) | ConvertTo-PSDataFrame
        { $bad['Units'].Sum() } | Should -Throw '*non-numeric*'
    }
}

Describe 'PSPandas concatenation' {
    It 'exports the canonical command and concise aliases' {
        (Get-Command ConvertTo-PSDataFrameConcat -Module PSPandas).CommandType | Should -Be 'Function'
        (Get-Command Concat -Module PSPandas).CommandType | Should -Be 'Alias'
        (Get-Command Concat -Module PSPandas).Definition | Should -Be 'ConvertTo-PSDataFrameConcat'
        (Get-Command Concat-PSDataFrame -Module PSPandas).Definition | Should -Be 'ConvertTo-PSDataFrameConcat'
    }

    It 'appends rows, unions columns, and fills missing values' {
        $left = @(
            [pscustomobject][ordered]@{ OrderId = 'A'; Region = 'West'; Amount = [decimal]10.50 }
        ) | ConvertTo-PSDataFrame
        $right = @(
            [pscustomobject][ordered]@{ OrderId = 'B'; Region = 'East'; Channel = 'Online'; Amount = [decimal]20.25 }
        ) | ConvertTo-PSDataFrame

        $combined = Concat-PSDataFrame -DataFrame $left, $right

        ($combined.Columns -join ',') | Should -Be 'OrderId,Region,Amount,Channel'
        $combined.Count | Should -Be 2
        $combined.Rows[0].OrderId | Should -Be 'A'
        $combined.Rows[0].Channel | Should -Be $null
        $combined.Rows[1].OrderId | Should -Be 'B'
        $combined.Rows[1].Channel | Should -Be 'Online'
        $combined.Rows[0].Amount | Should -BeOfType [decimal]
        ($combined | Concat).Count | Should -Be 2
    }

    It 'supports sorted output columns and empty schemas' {
        $unsorted = ConvertTo-PSDataFrame -InputObject ([pscustomobject][ordered]@{ Zulu = 1; Alpha = 2 })
        $sorted = $unsorted | Concat -Sort
        ($sorted.Columns -join ',') | Should -Be 'Alpha,Zulu'

        $emptyLeft = ConvertTo-PSDataFrame -Columns LeftOnly
        $emptyRight = ConvertTo-PSDataFrame -Columns RightOnly
        $empty = $emptyLeft, $emptyRight | Concat
        ($empty.Columns -join ',') | Should -Be 'LeftOnly,RightOnly'
        $empty.Count | Should -Be 0
    }
}

Describe 'PSPandas profiling' {
    It 'profiles numeric, DateTime, text, and null values' {
        $rows = @(
            [pscustomobject][ordered]@{ Amount = [int32]10; OrderDate = [datetime]'2024-01-02'; Status = 'Open' }
            [pscustomobject][ordered]@{ Amount = $null; OrderDate = [datetime]'2024-01-01'; Status = 'Closed' }
            [pscustomobject][ordered]@{ Amount = [int32]15; OrderDate = [datetime]'2024-01-03'; Status = $null }
        ) | ConvertTo-PSDataFrame
        $profileFrame = $rows | Get-PSDataFrameProfile -SampleCount 2

        $profileFrame.PSTypeNames | Should -Contain 'PSPandas.Profile'
        ($profileFrame.Columns -join ',') | Should -Be 'Column,Type,RowCount,NullCount,DistinctCount,Minimum,Maximum,Average,Sum,SampleValues,Earliest,Latest'
        $amount = @($profileFrame.Rows | Where-Object Column -eq 'Amount')[0]
        $amount.Type | Should -Be 'Numeric'
        $amount.RowCount | Should -Be 3
        $amount.NullCount | Should -Be 1
        $amount.DistinctCount | Should -Be 2
        @($amount.SampleValues).Count | Should -Be 2
        $amount.Minimum | Should -Be 10
        $amount.Maximum | Should -Be 15
        $amount.Average | Should -Be 12.5
        $amount.Sum | Should -Be 25

        $date = @($profileFrame.Rows | Where-Object Column -eq 'OrderDate')[0]
        $date.Type | Should -Be 'DateTime'
        $date.NullCount | Should -Be 0
        $date.Minimum | Should -Be ([datetime]'2024-01-01')
        $date.Maximum | Should -Be ([datetime]'2024-01-03')
        $date.Minimum.GetType().FullName | Should -Be 'System.DateTime'
        $date.Maximum.GetType().FullName | Should -Be 'System.DateTime'
        $date.Average | Should -Be $null
        $date.Sum | Should -Be $null
        $date.Earliest | Should -Be ([datetime]'2024-01-01')
        $date.Latest | Should -Be ([datetime]'2024-01-03')

        $status = @($profileFrame.Rows | Where-Object Column -eq 'Status')[0]
        $status.Type | Should -Be 'String'
        $status.NullCount | Should -Be 1
        $status.DistinctCount | Should -Be 2
        @($status.SampleValues).Count | Should -Be 2
    }

    It 'profiles DateOnly columns with typed minimum and maximum values' {
        $rows = @(
            [pscustomobject][ordered]@{ OrderDate = [System.DateOnly]::new(2026, 2, 15) }
            [pscustomobject][ordered]@{ OrderDate = [System.DateOnly]::new(2026, 1, 5) }
            [pscustomobject][ordered]@{ OrderDate = [System.DateOnly]::new(2026, 7, 2) }
        ) | ConvertTo-PSDataFrame

        $profileRow = @($rows | Get-PSDataFrameProfile -AsRows)[0]
        $profileRow.Type | Should -Be 'DateOnly'
        $profileRow.Minimum | Should -Be ([System.DateOnly]::new(2026, 1, 5))
        $profileRow.Maximum | Should -Be ([System.DateOnly]::new(2026, 7, 2))
        $profileRow.Minimum.GetType().FullName | Should -Be 'System.DateOnly'
        $profileRow.Maximum.GetType().FullName | Should -Be 'System.DateOnly'
        $profileRow.Average | Should -Be $null
        $profileRow.Sum | Should -Be $null
        $profileRow.Earliest | Should -Be $profileRow.Minimum
        $profileRow.Latest | Should -Be $profileRow.Maximum
    }

    It 'uses the native reader for direct path input without PSFlatFile' {
        $path = Join-Path $TestDrive 'typed-orders.csv'
        @(
            'OrderDate,Amount'
            '2026-02-15,10.50'
            '2026-01-05,20.25'
            '2026-07-02,30.00'
        ) | Set-Content -LiteralPath $path

        $frame = ConvertTo-PSDataFrame -Path $path
        $frame.GetType().FullName | Should -Be 'PSPandas.DataFrame'
        $frame.Rows[0].OrderDate.GetType().FullName | Should -Be 'System.DateOnly'

        $profileRow = @(Get-PSDataFrameProfile -Path $path -AsRows | Where-Object Column -eq 'OrderDate')[0]
        $profileRow.Minimum | Should -Be ([System.DateOnly]::new(2026, 1, 5))
        $profileRow.Maximum | Should -Be ([System.DateOnly]::new(2026, 7, 2))
    }

    It 'imports a typed flat file through Import-PSDataFrame without PSFlatFile' {
        $path = Join-Path $TestDrive 'import-psdataframe.csv'
        @(
            'Region,Units,OrderDate'
            'East,2,2026-01-05'
            'West,3,2026-02-12'
        ) | Set-Content -LiteralPath $path

        $imported = Import-PSDataFrame $path
        $imported.GetType().FullName | Should -Be 'PSPandas.DataFrame'
        ($imported.Columns -join ',') | Should -Be 'Region,Units,OrderDate'
        $imported.Rows[0].Units.GetType().FullName | Should -Be 'System.Int32'
        $imported.Rows[0].OrderDate.GetType().FullName | Should -Be 'System.DateOnly'
        @($imported.Rows).Count | Should -Be 2
    }

    It 'reads the RetailOrders fixture with native practical types' {
        $projectRoot = Split-Path (Resolve-Path $modulePath) -Parent
        $retailPath = Join-Path $projectRoot 'examples\data\RetailOrders.csv'
        $retail = ConvertTo-PSDataFrame $retailPath

        @($retail.Rows).Count | Should -Be 144
        $retail.Rows[0].'Row ID'.GetType().FullName | Should -Be 'System.Int32'
        $retail.Rows[0].Quantity.GetType().FullName | Should -Be 'System.Int32'
        $retail.Rows[0].'Postal Code'.GetType().FullName | Should -Be 'System.Int32'
        $retail.Rows[0].'Order Date'.GetType().FullName | Should -Be 'System.DateOnly'
        $retail.Rows[0].'Ship Date'.GetType().FullName | Should -Be 'System.DateOnly'
        $retail.Rows[0].Sales.GetType().FullName | Should -Be 'System.Decimal'
        $retail.Rows[0].Discount.GetType().FullName | Should -Be 'System.Decimal'
        $retail.Rows[0].Profit.GetType().FullName | Should -Be 'System.Decimal'
    }

    It 'supports native TSV, explicit schema, generic names, and typed nulls' {
        $path = Join-Path $TestDrive 'native.tsv'
        @(
            "Name`tUnits`tActive`tWhen`tAmount"
            "Alpha`t2`ttrue`t2026-01-05T10:30:00`t10.50"
            "Beta`t`tfalse`t2026-01-06T11:45:00`t"
        ) | Set-Content -LiteralPath $path

        $frame = ConvertTo-PSDataFrame $path -NameMode Generic
        ($frame.Columns -join ',') | Should -Be 'P1,P2,P3,P4,P5'
        $frame.Rows[0].P2.GetType().FullName | Should -Be 'System.Int32'
        $frame.Rows[0].P3.GetType().FullName | Should -Be 'System.Boolean'
        $frame.Rows[0].P4.GetType().FullName | Should -Be 'System.DateTime'
        $frame.Rows[1].P2 | Should -Be $null
        $frame.Rows[1].P5 | Should -Be $null

        $schemaFrame = ConvertTo-PSDataFrame $path -Schema ([ordered]@{
            Name = 'String'; Units = 'Int32'; Active = 'Boolean'; When = 'DateTime'; Amount = 'Decimal'
        })
        $schemaFrame.Rows[0].Amount.GetType().FullName | Should -Be 'System.Decimal'
        $schemaFrame.Rows[1].Units | Should -Be $null
    }

    It 'rejects unsupported native file extensions clearly' {
        $path = Join-Path $TestDrive 'data.json'
        '{"Region":"East"}' | Set-Content -LiteralPath $path
        { ConvertTo-PSDataFrame $path } | Should -Throw "*Unsupported delimited file extension '*.json'*"
        { Import-PSDataFrame $path } | Should -Throw "*Unsupported delimited file extension '*.json'*"
        { Get-PSDataFrameProfile $path -AsRows } | Should -Throw "*Unsupported delimited file extension '*.json'*"
    }

    It 'reads HTTP URI sources through the native reader across all file-oriented commands' {
        Mock -CommandName Invoke-WebRequest -ModuleName PSPandas -MockWith {
            $content = "Region,Units,OrderDate`nEast,2,2026-01-05`nWest,3,2026-02-12"
            $stream = [System.IO.MemoryStream]::new([System.Text.UTF8Encoding]::new($false).GetBytes($content))
            [pscustomobject]@{
                Headers          = @{ 'Content-Type' = 'text/csv' }
                Content          = $content
                RawContentStream = $stream
            }
        }

        $uri = [uri]'https://example.com/orders.csv'
        $converted = ConvertTo-PSDataFrame -Uri $uri
        $imported = Import-PSDataFrame -Uri $uri
        $profileRows = @(Get-PSDataFrameProfile -Uri $uri -AsRows)

        @($converted.Rows).Count | Should -Be 2
        @($imported.Rows).Count | Should -Be 2
        $converted.Rows[0].Units.GetType().FullName | Should -Be 'System.Int32'
        $imported.Rows[0].OrderDate.GetType().FullName | Should -Be 'System.DateOnly'
        ($profileRows | Where-Object Column -eq 'OrderDate').Type | Should -Be 'DateOnly'
        Assert-MockCalled Invoke-WebRequest -ModuleName PSPandas -Times 3 -Exactly
    }

    It 'translates standard GitHub blob URLs to raw download URLs' {
        Mock -CommandName Invoke-WebRequest -ModuleName PSPandas -MockWith {
            $content = "Player,Team,HomeRuns`nAlice,North,12`nBob,South,9"
            [pscustomobject]@{
                Headers          = @{ 'Content-Type' = 'text/csv' }
                Content          = $content
                RawContentStream = [System.IO.MemoryStream]::new([System.Text.UTF8Encoding]::new($false).GetBytes($content))
            }
        }

        $blobUri = [uri]'https://github.com/dfinke/PSKit/blob/master/data/baseball.csv'
        $frame = ConvertTo-PSDataFrame -Uri $blobUri -TimeoutSec 7

        @($frame.Rows).Count | Should -Be 2
        $frame.Rows[0].HomeRuns.GetType().FullName | Should -Be 'System.Int32'
        Assert-MockCalled Invoke-WebRequest -ModuleName PSPandas -Times 1 -Exactly -ParameterFilter {
            $Uri.AbsoluteUri -eq 'https://raw.githubusercontent.com/dfinke/PSKit/master/data/baseball.csv' -and
            $TimeoutSec -eq 7
        }
    }

    It 'rejects HTML responses instead of passing them to a data reader' {
        Mock -CommandName Invoke-WebRequest -ModuleName PSPandas -MockWith {
            $content = '<!doctype html><html><head><title>GitHub</title></head><body>Blob page</body></html>'
            [pscustomobject]@{
                Headers          = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                Content          = $content
                RawContentStream = [System.IO.MemoryStream]::new([System.Text.UTF8Encoding]::new($false).GetBytes($content))
            }
        }

        { Import-PSDataFrame -Uri ([uri]'https://example.com/orders.csv') } |
            Should -Throw '*received an HTML page*instead of a data file*'
    }

    It 'rejects unsupported URI schemes and reports download failures clearly' {
        { ConvertTo-PSDataFrame -Uri ([uri]'ftp://example.com/orders.csv') } |
            Should -Throw '*only absolute http:// and https:// URIs*'

        Mock -CommandName Invoke-WebRequest -ModuleName PSPandas -MockWith {
            throw [System.Net.WebException]::new('The remote server returned an error: (503) Service Unavailable.')
        }
        { Import-PSDataFrame -Uri ([uri]'https://example.com/orders.csv') } |
            Should -Throw "*could not download URI*503*"
    }

    It 'validates Import-PSDataFrame file-type-specific parameters' {
        $xlsxPath = Join-Path $TestDrive 'validation.xlsx'
        $xlsmPath = Join-Path $TestDrive 'validation.xlsm'
        'placeholder' | Set-Content -LiteralPath $xlsxPath
        'placeholder' | Set-Content -LiteralPath $xlsmPath

        foreach ($path in @($xlsxPath, $xlsmPath)) {
            { Import-PSDataFrame $path -Schema ([ordered]@{ Amount = 'Decimal' }) -WorksheetName Orders } |
                Should -Throw '*-Schema*Excel file extension*'
            { Import-PSDataFrame $path -AsWorkbook -WorksheetName Orders } |
                Should -Throw '*-AsWorkbook*cannot be combined*-WorksheetName*'
        }

        $flatPath = Join-Path $TestDrive 'validation.csv'
        'Region,Amount', 'East,10' | Set-Content -LiteralPath $flatPath
        { Import-PSDataFrame $flatPath -WorksheetName Orders } |
            Should -Throw "*'-WorksheetName'*'.csv'*"
        { Import-PSDataFrame $flatPath -AsWorkbook } |
            Should -Throw "*'-AsWorkbook'*'.csv'*"
    }

    It 'imports an Excel worksheet when ImportExcel is available' {
        $importExcelManifest = Get-Module -ListAvailable -Name ImportExcel |
            Sort-Object Version -Descending |
            Select-Object -First 1
        if ($null -eq $importExcelManifest) {
            Set-ItResult -Skipped -Because 'ImportExcel is not installed.'
            return
        }

        Import-Module ImportExcel -Force
        $path = Join-Path $TestDrive 'typed-orders.xlsx'
        @(
            [pscustomobject][ordered]@{ Region = 'East'; Units = 2; Amount = 10.50 }
            [pscustomobject][ordered]@{ Region = 'West'; Units = 3; Amount = 20.25 }
        ) | Export-Excel -Path $path -WorksheetName Orders -AutoSize

        $imported = Import-PSDataFrame $path -WorksheetName Orders
        $imported.GetType().FullName | Should -Be 'PSPandas.DataFrame'
        ($imported.Columns -join ',') | Should -Be 'Region,Units,Amount'
        @($imported.Rows).Count | Should -Be 2
        $imported.Rows[0].Region | Should -Be 'East'
        $imported.Rows[1].Units | Should -Be 3

        $firstWorksheetImport = Import-PSDataFrame $path
        ($firstWorksheetImport.Columns -join ',') | Should -Be 'Region,Units,Amount'
        @($firstWorksheetImport.Rows).Count | Should -Be 2
        $firstWorksheetImport.Rows[0].Region | Should -Be 'East'

        $workbookBytes = [System.IO.File]::ReadAllBytes($path)
        Mock -CommandName Invoke-WebRequest -ModuleName PSPandas -MockWith {
            [pscustomobject]@{
                Headers          = @{ 'Content-Type' = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }
                Content          = $null
                RawContentStream = [System.IO.MemoryStream]::new($workbookBytes)
            }
        }
        $uriImport = Import-PSDataFrame -Uri ([uri]'https://example.com/typed-orders.xlsx') -WorksheetName Orders
        ($uriImport.Columns -join ',') | Should -Be 'Region,Units,Amount'
        @($uriImport.Rows).Count | Should -Be 2
    }

    It 'preserves typed dates in the retail workbook fixture' {
        $importExcelManifest = Get-Module -ListAvailable -Name ImportExcel |
            Sort-Object Version -Descending |
            Select-Object -First 1
        if ($null -eq $importExcelManifest) {
            Set-ItResult -Skipped -Because 'ImportExcel is not installed.'
            return
        }

        Import-Module ImportExcel -Force
        $path = Join-Path $PSScriptRoot '..\examples\data\RetailWorkbook.xlsx'
        $salesRows = @(Import-Excel $path -WorksheetName Sales)
        $orderLineRows = @(Import-Excel $path -WorksheetName OrderLines)
        $returnRows = @(Import-Excel $path -WorksheetName Returns)

        @($salesRows).'Order Date' | ForEach-Object { $_ | Should -BeOfType [datetime] }
        @($salesRows).'Ship Date' | ForEach-Object { $_ | Should -BeOfType [datetime] }
        @($orderLineRows).'Order Date' | ForEach-Object { $_ | Should -BeOfType [datetime] }
        @($orderLineRows).'Ship Date' | ForEach-Object { $_ | Should -BeOfType [datetime] }
        @($returnRows).'Returned Date' | ForEach-Object { $_ | Should -BeOfType [datetime] }

        $book = Import-PSDataFrame $path -AsWorkbook
        $book.Sales.Rows[0].'Order Date' | Should -BeOfType [datetime]
        $book.Sales.Rows[0].'Ship Date' | Should -BeOfType [datetime]
        $book.Returns.Rows[0].'Returned Date' | Should -BeOfType [datetime]
    }

    It 'imports all worksheets as an ordered workbook with tab-completable sheet properties' {
        $importExcelManifest = Get-Module -ListAvailable -Name ImportExcel |
            Sort-Object Version -Descending |
            Select-Object -First 1
        if ($null -eq $importExcelManifest) {
            Set-ItResult -Skipped -Because 'ImportExcel is not installed.'
            return
        }

        Import-Module ImportExcel -Force
        $path = Join-Path $TestDrive 'yearly-sales.xlsx'
        @(
            [pscustomobject][ordered]@{ Region = 'East'; Amount = 20.50 }
            [pscustomobject][ordered]@{ Region = 'West'; Amount = 15.25 }
        ) | Export-Excel -Path $path -WorksheetName January -AutoSize
        @(
            [pscustomobject][ordered]@{ Region = 'East'; Amount = 45.00 }
            [pscustomobject][ordered]@{ Region = 'North'; Amount = 30.00 }
        ) | Export-Excel -Path $path -WorksheetName February -AutoSize

        $book = Import-PSDataFrame $path -AsWorkbook
        $book.GetType().FullName | Should -Be 'PSPandas.Workbook'
        @($book.Worksheets.Names) | Should -Be @('January', 'February')
        $book.Worksheets.Count | Should -Be 2
        $book.January.GetType().FullName | Should -Be 'PSPandas.DataFrame'
        $book.Worksheets['February'].Rows[1].Region | Should -Be 'North'
        $book['January'].Rows[0].Amount | Should -Be 20.50
        @($book.Worksheets.Items).Count | Should -Be 2
        $book.Worksheets.Items[0].Name | Should -Be 'January'
        $book.Worksheets.Items[1].Count | Should -Be 2

        $completionVariable = 'pspandasWorkbookForCompletion'
        Set-Variable -Name $completionVariable -Value $book -Scope Global
        try {
            $completionInput = "`$$completionVariable."
            $completion = [System.Management.Automation.CommandCompletion]::CompleteInput(
                $completionInput,
                $completionInput.Length,
                $null)
            @($completion.CompletionMatches.CompletionText) | Should -Contain 'January'
            @($completion.CompletionMatches.CompletionText) | Should -Contain 'February'
        } finally {
            Remove-Variable -Name $completionVariable -Scope Global -ErrorAction SilentlyContinue
        }
    }

    It 'renders all profile rows in one structured table with typed bounds' {
        $rows = @(
            [pscustomobject][ordered]@{ Amount = [int32]10; OrderDate = [datetime]'2024-01-02'; Status = 'Open' }
            [pscustomobject][ordered]@{ Amount = [int32]20; OrderDate = [datetime]'2024-01-04'; Status = 'Closed' }
        ) | ConvertTo-PSDataFrame

        $profileFrame = $rows | Get-PSDataFrameProfile -SampleCount 1
        $display = $profileFrame | Out-String
        $display | Should -Match 'Column'
        $display | Should -Match 'Type'
        $display | Should -Match 'Minimum'
        $display | Should -Match 'Maximum'
        $display | Should -Match 'Average'
        $display | Should -Match 'Sum'
        $display | Should -Match 'SampleValues'
        $display | Should -Match 'OrderDate'
        $display | Should -Match 'Open'
        $display | Should -Not -Match 'Numeric columns:|Date/time columns:|Other columns:'
        $display | Should -Not -Match 'Earliest|Latest'
        $display.IndexOf('Minimum') | Should -BeLessThan $display.IndexOf('SampleValues')
    }

    It 'right-aligns DateOnly and numeric profile statistics in default and AsRows views' {
        $rows = @(
            [pscustomobject][ordered]@{ Amount = [decimal]10.5; OrderDate = [System.DateOnly]::new(2026, 1, 5); Status = 'Open' }
            [pscustomobject][ordered]@{ Amount = [decimal]20.25; OrderDate = [System.DateOnly]::new(2026, 7, 2); Status = 'Closed' }
        ) | ConvertTo-PSDataFrame

        $profile = $rows | Get-PSDataFrameProfile
        $profileRows = @($rows | Get-PSDataFrameProfile -AsRows)
        $header = (($profileRows | Format-Table | Out-String -Width 240) -split "`r?`n" | Where-Object { $_ -match 'Column\s+Type\s+RowCount' } | Select-Object -First 1)
        $dateLine = (($profileRows | Format-Table | Out-String -Width 240) -split "`r?`n" | Where-Object { $_ -match '^OrderDate\s' } | Select-Object -First 1)
        $amountLine = (($profile | Out-String -Width 240) -split "`r?`n" | Where-Object { $_ -match '^Amount\s' } | Select-Object -First 1)
        $dateMinimumText = $profileRows[1].Minimum.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        $dateMaximumText = $profileRows[1].Maximum.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)

        $dateLine | Should -Match '2026-01-05'
        $dateLine | Should -Match '2026-07-02'
        ($header.IndexOf('Minimum') + 'Minimum'.Length) | Should -Be ($dateLine.IndexOf($dateMinimumText) + $dateMinimumText.Length)
        ($header.IndexOf('Maximum') + 'Maximum'.Length) | Should -Be ($dateLine.IndexOf($dateMaximumText) + $dateMaximumText.Length)
        $profileRows[1].Minimum.GetType().FullName | Should -Be 'System.DateOnly'
        $profileRows[1].Maximum.GetType().FullName | Should -Be 'System.DateOnly'
        $profile.Rows[0].Minimum | Should -Be 10.5
        $profile.Rows[0].Maximum | Should -Be 20.25
        $profileRows[1].PSObject.Properties.Name -join ',' | Should -Be 'Column,Type,RowCount,NullCount,DistinctCount,Minimum,Maximum,Average,Sum,SampleValues,Earliest,Latest'
    }

    It 'renders DateTime bounds as ISO date-time values without changing raw types' {
        $rows = @(
            [pscustomobject][ordered]@{ When = [datetime]'2026-01-05T12:34:56'; Value = 10 }
            [pscustomobject][ordered]@{ When = [datetime]'2026-07-02T08:09:10'; Value = 20 }
        ) | ConvertTo-PSDataFrame

        $profile = $rows | Get-PSDataFrameProfile
        $profileRows = @($rows | Get-PSDataFrameProfile -AsRows)
        $display = $profile | Out-String -Width 240
        $header = ($display -split "`r?`n" | Where-Object { $_ -match 'Column\s+Type\s+RowCount' } | Select-Object -First 1)
        $dateLine = ($display -split "`r?`n" | Where-Object { $_ -match '^When\s' } | Select-Object -First 1)

        $dateLine | Should -Match '2026-01-05T12:34:56'
        $dateLine | Should -Match '2026-07-02T08:09:10'
        ($header.IndexOf('Minimum') + 'Minimum'.Length) | Should -Be ($dateLine.IndexOf('2026-01-05T12:34:56') + '2026-01-05T12:34:56'.Length)
        ($header.IndexOf('Maximum') + 'Maximum'.Length) | Should -Be ($dateLine.IndexOf('2026-07-02T08:09:10') + '2026-07-02T08:09:10'.Length)
        $profileRows[0].Minimum.GetType().FullName | Should -Be 'System.DateTime'
        $profileRows[0].Maximum.GetType().FullName | Should -Be 'System.DateTime'
    }

    It 'emits ordinary profile rows with AsRows while the default remains a DataFrame' {
        $rows = @(
            [pscustomobject][ordered]@{ Amount = [int32]10; OrderDate = [datetime]'2024-01-02'; Status = 'Open' }
            [pscustomobject][ordered]@{ Amount = [int32]20; OrderDate = [datetime]'2024-01-04'; Status = 'Closed' }
        ) | ConvertTo-PSDataFrame

        $defaultProfile = $rows | Get-PSDataFrameProfile
        $defaultProfile.GetType().FullName | Should -Be 'PSPandas.DataFrame'

        $profileRows = @($rows | Get-PSDataFrameProfile -AsRows -SampleCount 1)
        $profileRows.Count | Should -Be 3
        $profileRows[0].PSTypeNames | Should -Not -Contain 'PSPandas.DataFrame'
        ($profileRows[0].PSObject.Properties.Name -join ',') | Should -Be 'Column,Type,RowCount,NullCount,DistinctCount,Minimum,Maximum,Average,Sum,SampleValues,Earliest,Latest'

        $dateRows = @($rows | Get-PSDataFrameProfile -AsRows | Where-Object Type -eq 'DateTime')
        $dateRows.Count | Should -Be 1
        $dateRows[0].Minimum.GetType().FullName | Should -Be 'System.DateTime'
        $dateRows[0].Maximum | Should -Be ([datetime]'2024-01-04')
    }

    It 'handles empty, all-null, and mixed columns without throwing' {
        $empty = ConvertTo-PSDataFrame -Columns EmptyColumn
        $emptyProfile = $empty | Get-PSDataFrameProfile
        $emptyRow = $emptyProfile.Rows[0]
        $emptyRow.Type | Should -Be 'Empty'
        $emptyRow.RowCount | Should -Be 0
        $emptyRow.NullCount | Should -Be 0
        $emptyRow.DistinctCount | Should -Be 0
        $emptyRow.Sum | Should -Be $null

        $allNull = @(
            [pscustomobject][ordered]@{ Value = $null }
            [pscustomobject][ordered]@{ Value = $null }
        ) | ConvertTo-PSDataFrame
        $allNullRow = ($allNull | Get-PSDataFrameProfile).Rows[0]
        $allNullRow.Type | Should -Be 'Null'
        $allNullRow.RowCount | Should -Be 2
        $allNullRow.NullCount | Should -Be 2

        $mixed = @(
            [pscustomobject][ordered]@{ Value = [int32]1 }
            [pscustomobject][ordered]@{ Value = 'two' }
            [pscustomobject][ordered]@{ Value = [int32]3 }
        ) | ConvertTo-PSDataFrame
        $mixedRow = ($mixed | Get-PSDataFrameProfile).Rows[0]
        $mixedRow.Type | Should -Be 'Mixed'
        $mixedRow.DistinctCount | Should -Be 3
        $mixedRow.Sum | Should -Be $null
        @($mixedRow.SampleValues).Count | Should -Be 3
    }
}

Describe 'PSPandas core transformations' {
    It 'filters rows and preserves the schema' {
        $result = $frame | Find-PSDataFrame { $_.Amount -gt 20 }
        @($result.Rows).Count | Should -Be 1
        $result.Rows[0].Product | Should -Be 'C'
        ($result.Columns -join ',') | Should -Be ($frame.Columns -join ',')
    }

    It 'selects and reorders columns' {
        $result = $frame | Select-PSDataFrame Product, Region
        ($result.Columns -join ',') | Should -Be 'Product,Region'
        $result.Rows[0].Product | Should -Be 'A'
        $result.Rows[0].Region | Should -Be 'East'
    }

    It 'sorts ascending and descending' {
        $ascending = $frame | Set-PSDataFrameOrder Amount
        @($ascending.Rows | ForEach-Object Amount) | Should -Be @(15, 20, 45)
        $descending = $frame | Set-PSDataFrameOrder Amount -Descending
        @($descending.Rows | ForEach-Object Amount) | Should -Be @(45, 20, 15)
    }

    It 'adds calculated columns from the current row' {
        $result = $frame | Add-PSDataFrameColumn -Name UnitPrice -Expression { $_.Amount / $_.Quantity }
        ($result.Columns -join ',') | Should -Be 'Region,Product,Quantity,Amount,UnitPrice'
        $result.Rows[0].UnitPrice | Should -Be 10
        $parameterExpression = $frame | Add-PSDataFrameColumn -Name DoubleAmount -Expression { param($row) $row.Amount * 2 }
        $parameterExpression.Rows[0].DoubleAmount | Should -Be 40
        { $frame | Add-PSDataFrameColumn -Name Amount -Expression { 1 } } | Should -Throw
    }

    It 'groups in first-seen order' {
        $groups = @($frame | Group-PSDataFrame -By Region)
        $groups.Count | Should -Be 2
        $groups[0].Key | Should -Be 'East'
        $groups[0].Count | Should -Be 2
        $groups[0].DataFrame.Rows[1].Product | Should -Be 'C'
        $groups[1].Key | Should -Be 'West'
    }

    It 'summarizes with built-in aggregates' {
        $summary = $frame | Measure-PSDataFrame -By Region -Aggregate ([ordered]@{
            Orders  = @{ Function = 'Count' }
            Revenue = @{ Property = 'Amount'; Function = 'Sum' }
            Average = @{ Property = 'Amount'; Function = 'Average' }
        })
        @($summary.Rows).Count | Should -Be 2
        $summary.Rows[0].Region | Should -Be 'East'
        $summary.Rows[0].Orders | Should -Be 2
        $summary.Rows[0].Revenue | Should -Be 65
        $summary.Rows[0].Average | Should -Be 32.5
    }

    It 'preserves declared aggregate order in columns and row properties' {
        $summary = $frame | Measure-PSDataFrame -By Region -Aggregate ([ordered]@{
            Orders  = @{ Function = 'Count' }
            Revenue = @{ Property = 'Amount'; Function = 'Sum' }
        })
        ($summary.Columns -join ',') | Should -Be 'Region,Orders,Revenue'
        ($summary.Rows[0].PSObject.Properties.Name -join ',') | Should -Be 'Region,Orders,Revenue'
    }

    It 'supports custom aggregate scriptblocks and global summaries' {
        $summary = $frame | Measure-PSDataFrame -Aggregate ([ordered]@{
            Products = { param($rows) (@($rows | ForEach-Object Product) -join '/') }
        })
        $summary.Rows[0].Products | Should -Be 'A/B/C'
    }

    It 'supports concise ungrouped and grouped summaries with multiple properties' {
        $orders = @(
            [pscustomobject][ordered]@{ State = 'East'; OrderId = 1001; CustomerId = 'C01'; Amount = 20; Tax = 2 }
            [pscustomobject][ordered]@{ State = 'East'; OrderId = 1002; CustomerId = 'C02'; Amount = 15; Tax = 1 }
            [pscustomobject][ordered]@{ State = 'West'; OrderId = 1003; CustomerId = 'C03'; Amount = 7; Tax = 1 }
        ) | ConvertTo-PSDataFrame

        $ungrouped = $orders | Summarize -Count OrderId, CustomerId -Sum Amount, Tax
        ($ungrouped.Columns -join ',') | Should -Be 'Count_OrderId,Count_CustomerId,Sum_Amount,Sum_Tax'
        $ungrouped.Rows[0].Count_OrderId | Should -Be 3
        $ungrouped.Rows[0].Sum_Amount | Should -Be 42
        $ungrouped.Rows[0].Sum_Tax | Should -Be 4

        $grouped = $orders | Summarize -By State -Count OrderId, CustomerId -Sum Amount, Tax
        ($grouped.Columns -join ',') | Should -Be 'State,Count_OrderId,Count_CustomerId,Sum_Amount,Sum_Tax'
        $grouped.Rows[0].State | Should -Be 'East'
        $grouped.Rows[0].Sum_Amount | Should -Be 35
        $grouped.Rows[1].State | Should -Be 'West'
        $grouped.Rows[1].Sum_Tax | Should -Be 1
    }

    It 'combines friendly and advanced aggregates without allowing collisions' {
        $mixed = $frame | Summarize -Count Product -Aggregate ([ordered]@{
            Revenue = @{ Property = 'Amount'; Function = 'Sum' }
        })
        ($mixed.Columns -join ',') | Should -Be 'Count_Product,Revenue'
        { $frame | Summarize -Sum Amount -Aggregate ([ordered]@{
            Sum_Amount = @{ Property = 'Amount'; Function = 'Sum' }
        }) } | Should -Throw '*collides*'
    }

    It 'infers a numeric source property from a function-only aggregate spec' {
        $typedRows = @(
            [pscustomobject][ordered]@{ State = 'TX'; Units = [int32]3 }
            [pscustomobject][ordered]@{ State = 'TX'; Units = [int32]4 }
            [pscustomobject][ordered]@{ State = 'WA'; Units = [int32]2 }
        )
        $summary = $typedRows | ConvertTo-PSDataFrame | Measure-PSDataFrame -By State -Aggregate ([ordered]@{
            Units = @{ Function = 'Sum' }
        })
        ($summary.Columns -join ',') | Should -Be 'State,Units'
        $summary.Rows[0].Units | Should -Be 7
        $summary.Rows[1].Units | Should -Be 2
        { $typedRows | ConvertTo-PSDataFrame | Measure-PSDataFrame -By State -Aggregate ([ordered]@{
            Missing = @{ Function = 'Sum' }
        }) } | Should -Throw '*Column*'
    }
}

Describe 'PSPandas joins and edge cases' {
    BeforeAll {
        $right = @(
            [pscustomobject][ordered]@{ Region = 'East'; Manager = 'Lee'; Target = 60 }
            [pscustomobject][ordered]@{ Region = 'North'; Manager = 'Pat'; Target = 10 }
        ) | ConvertTo-PSDataFrame
    }

    It 'performs an inner join and suffixes collisions' {
        $joined = Join-PSDataFrame -Left $frame -Right $right -On Region
        @($joined.Rows).Count | Should -Be 2
        ($joined.Columns -join ',') | Should -Be 'Region,Product,Quantity,Amount,Manager,Target'
        $joined.Rows[0].Manager | Should -Be 'Lee'
    }

    It 'performs left, right, and full joins' {
        $left = Join-PSDataFrame -Left $frame -Right $right -On Region -JoinType Left
        @($left.Rows).Count | Should -Be 3
        $left.Rows[1].Manager | Should -Be $null

        $rightResult = Join-PSDataFrame -Left $frame -Right $right -On Region -JoinType Right
        @($rightResult.Rows).Count | Should -Be 3
        $rightResult.Rows[2].Region | Should -Be $null

        $full = Join-PSDataFrame -Left $frame -Right $right -On Region -JoinType Full
        @($full.Rows).Count | Should -Be 4
    }

    It 'preserves schemas through empty transformations' {
        $empty = $frame | Find-PSDataFrame { $false }
        @($empty.Rows).Count | Should -Be 0
        ($empty.Columns -join ',') | Should -Be ($frame.Columns -join ',')
        $emptySummary = $empty | Measure-PSDataFrame -By Region -Aggregate @{ Total = @{ Property = 'Amount'; Function = 'Sum' } }
        @($emptySummary.Rows).Count | Should -Be 0
        ($emptySummary.Columns -join ',') | Should -Be 'Region,Total'
    }

    It 'supports pipeline composition through conversion' {
        $products = $frame |
            Find-PSDataFrame { $_.Quantity -gt 1 } |
            Select-PSDataFrame Product, Amount |
            ConvertFrom-PSDataFrame |
            ForEach-Object Product
        $products | Should -Be @('A', 'C')
    }
}
