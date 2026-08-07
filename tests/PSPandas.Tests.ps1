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

    It 'uses the typed file reader for direct path input when PSFlatFile is available' {
        $projectRoot = Split-Path (Resolve-Path $modulePath) -Parent
        $readerManifest = Join-Path (Split-Path $projectRoot -Parent) 'PSFlatFile\PSFlatFile.psd1'
        if (-not (Test-Path -LiteralPath $readerManifest)) {
            Set-ItResult -Skipped -Because 'PSFlatFile is not available beside the PSPandas repository.'
            return
        }

        Import-Module $readerManifest -Force
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

    It 'imports a typed flat file through Import-PSDataFrame' {
        $projectRoot = Split-Path (Resolve-Path $modulePath) -Parent
        $readerManifest = Join-Path (Split-Path $projectRoot -Parent) 'PSFlatFile\PSFlatFile.psd1'
        if (-not (Test-Path -LiteralPath $readerManifest)) {
            Set-ItResult -Skipped -Because 'PSFlatFile is not available beside the PSPandas repository.'
            return
        }

        Import-Module $readerManifest -Force
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
