<#
.SYNOPSIS
Validates PSPandas wide pivot behavior and display options.

.DESCRIPTION
Runs Pester coverage for pivot command discovery, dimensions, aggregate forms,
ordering, margins, metadata, outline reports, grids, and validation failures.
#>

$describeAlias = Get-Alias -Name Describe -ErrorAction SilentlyContinue
if ($describeAlias -and $describeAlias.Source -eq 'PSPandas') {
    # Pester's Describe DSL must win during discovery when PSPandas is already imported.
    Remove-Item -Path Alias:Describe -Force
}

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\PSPandas.psd1'
    Import-Module $modulePath -Force

    $pivotRows = @(
        [pscustomobject][ordered]@{ Region = 'East'; State = 'NY'; Year = 2025; Quarter = 'Q1'; Channel = 'Online'; Revenue = 10; Units = 1; OrderId = 'A' }
        [pscustomobject][ordered]@{ Region = 'East'; State = 'NY'; Year = 2025; Quarter = 'Q1'; Channel = 'Online'; Revenue = 15; Units = 2; OrderId = 'B' }
        [pscustomobject][ordered]@{ Region = 'East'; State = 'NY'; Year = 2025; Quarter = 'Q2'; Channel = 'Store';  Revenue = 20; Units = 4; OrderId = 'C' }
        [pscustomobject][ordered]@{ Region = 'West'; State = 'CA'; Year = 2025; Quarter = 'Q1'; Channel = 'Store';  Revenue = 30; Units = 3; OrderId = 'D' }
    )
    $pivotFrame = $pivotRows | ConvertTo-PSDataFrame
}

Describe 'PSPandas wide pivot command surface' {
    It 'exports a warning-free canonical command and concise aliases' {
        (Get-Command ConvertTo-PSDataFrameWide -Module PSPandas).CommandType | Should -Be 'Function'
        (Get-Command Pivot -Module PSPandas).CommandType | Should -Be 'Alias'
        (Get-Command Pivot -Module PSPandas).Definition | Should -Be 'ConvertTo-PSDataFrameWide'
        (Get-Command Pivot-PSDataFrame -Module PSPandas).Definition | Should -Be 'ConvertTo-PSDataFrameWide'
        (Get-Command ConvertTo-PSDataFrameCrosstab -Module PSPandas).CommandType | Should -Be 'Function'
        (Get-Command Crosstab -Module PSPandas).CommandType | Should -Be 'Alias'
        (Get-Command Crosstab -Module PSPandas).Definition | Should -Be 'ConvertTo-PSDataFrameCrosstab'
        (Get-Command Crosstab-PSDataFrame -Module PSPandas).Definition | Should -Be 'ConvertTo-PSDataFrameCrosstab'
        (Get-Command xtab -Module PSPandas).CommandType | Should -Be 'Alias'
        (Get-Command xtab -Module PSPandas).Definition | Should -Be 'ConvertTo-PSDataFrameCrosstab'
        (Get-Help xtab -ErrorAction Stop).Name | Should -Be 'ConvertTo-PSDataFrameCrosstab'
        (Get-Help xtab -ErrorAction Stop).Parameters.Parameter.Name | Should -Contain 'Percent'
    }

    It 'counts index and column combinations and supports margins' {
        $speechData = ConvertTo-PSDataFrame -ColumnData ([ordered]@{
            speaker = 'upsy-daisy', 'upsy-daisy', 'upsy-daisy', 'upsy-daisy', 'tombliboo', 'tombliboo', 'makka-pakka', 'makka-pakka', 'makka-pakka', 'makka-pakka'
            utterance = 'pip', 'pip', 'onk', 'onk', 'ee', 'oo', 'pip', 'pip', 'onk', 'onk'
        })

        $cross = $speechData | Crosstab -Index speaker -Columns utterance -Margins -FillValue 0

        ($cross.Columns -join ',') | Should -Be 'speaker,pip,onk,ee,oo,Total'
        $cross.Rows[0].speaker | Should -Be 'upsy-daisy'
        $cross.Rows[0].pip | Should -Be 2
        $cross.Rows[0].onk | Should -Be 2
        $cross.Rows[0].Total | Should -Be 4
        $cross.Rows[0].pip | Should -BeOfType [int]
        $cross.Rows[0].Total | Should -BeOfType [int]
        $cross.Rows[1].ee | Should -Be 1
        $cross.Rows[1].oo | Should -Be 1
        $cross.Rows[2].pip | Should -Be 2
        $cross.Rows[2].onk | Should -Be 2
        $cross.Rows[3].Total | Should -Be 10
    }

    It 'uses integer zero for absent frequency combinations by default' {
        $source = @(
            [pscustomobject]@{ Source = 'A'; EntryType = 'Information' }
            [pscustomobject]@{ Source = 'A'; EntryType = 'Information' }
            [pscustomobject]@{ Source = 'A'; EntryType = 'Error' }
            [pscustomobject]@{ Source = 'B'; EntryType = 'Warning' }
        ) | ConvertTo-PSDataFrame

        $cross = $source | xtab Source EntryType

        $cross.Rows[0].Information | Should -Be 2
        $cross.Rows[0].Information | Should -BeOfType [int]
        $cross.Rows[0].Error | Should -Be 1
        $cross.Rows[0].Error | Should -BeOfType [int]
        $cross.Rows[0].Warning | Should -Be 0
        $cross.Rows[0].Warning | Should -BeOfType [int]
        $cross.Rows[1].Information | Should -Be 0
        $cross.Rows[1].Error | Should -Be 0
        $cross.Rows[1].Warning | Should -Be 1
    }

    It 'allows an explicit null fill value when blank cells are desired' {
        $source = @(
            [pscustomobject]@{ Source = 'A'; EntryType = 'Information' }
            [pscustomobject]@{ Source = 'B'; EntryType = 'Warning' }
        ) | ConvertTo-PSDataFrame

        $cross = $source | Crosstab Source EntryType -FillValue $null

        $cross.Rows[0].Warning | Should -Be $null
        $cross.Rows[1].Information | Should -Be $null
    }

    It 'normalizes crosstab counts across all, index rows, or columns' {
        $source = @(
            [pscustomobject]@{ Group = 'A'; Kind = 'X' }
            [pscustomobject]@{ Group = 'A'; Kind = 'X' }
            [pscustomobject]@{ Group = 'A'; Kind = 'Y' }
            [pscustomobject]@{ Group = 'B'; Kind = 'X' }
        ) | ConvertTo-PSDataFrame

        $all = $source | Crosstab Group Kind -Normalize All
        $index = $source | Crosstab Group Kind -Normalize Index
        $columns = $source | Crosstab Group Kind -Normalize Columns
        $allPercent = $source | Crosstab Group Kind -Normalize All -Percent
        $indexPercent = $source | Crosstab Group Kind -Normalize Index -Percent
        $columnsPercent = $source | Crosstab Group Kind -Normalize Columns -Percent

        $all.Rows[0].X | Should -Be 0.5
        $all.Rows[0].Y | Should -Be 0.25
        $all.Rows[1].X | Should -Be 0.25
        $all.Rows[1].Y | Should -Be 0
        $all.Rows[0].X | Should -BeOfType [double]
        $all.Metadata.Pivot.Normalize | Should -Be 'All'

        $index.Rows[0].X | Should -Be (2 / 3)
        $index.Rows[0].Y | Should -Be (1 / 3)
        $index.Rows[1].X | Should -Be 1
        $index.Rows[1].Y | Should -Be 0

        $columns.Rows[0].X | Should -Be (2 / 3)
        $columns.Rows[1].X | Should -Be (1 / 3)
        $columns.Rows[0].Y | Should -Be 1
        $columns.Rows[1].Y | Should -Be 0

        $allPercent.Rows[0].X | Should -Be 50
        $allPercent.Rows[0].Y | Should -Be 25
        $allPercent.Rows[1].X | Should -Be 25
        $allPercent.Rows[1].Y | Should -Be 0
        $allPercent.Rows[0].X | Should -BeOfType [double]
        $indexPercent.Rows[0].X | Should -Be ((2 / 3) * 100)
        $indexPercent.Rows[0].Y | Should -Be ((1 / 3) * 100)
        $indexPercent.Rows[1].X | Should -Be 100
        $indexPercent.Rows[1].Y | Should -Be 0
        $columnsPercent.Rows[0].X | Should -Be ((2 / 3) * 100)
        $columnsPercent.Rows[1].X | Should -Be ((1 / 3) * 100)
        $columnsPercent.Rows[0].Y | Should -Be 100
        $columnsPercent.Rows[1].Y | Should -Be 0
        $percentDisplayLines = @($indexPercent | Out-String -Width 200 -Stream)
        $percentDisplayLines | Should -Contain 'A      66.7 33.3'
        $percentDisplayLines | Should -Contain 'B     100.0  0.0'
        $percentDisplayLines -join "`n" | Should -Not -Match '%'
        $percentA = $percentDisplayLines | Where-Object { $_ -match '^A' }
        $percentB = $percentDisplayLines | Where-Object { $_ -match '^B' }
        ($percentA.IndexOf('66.7') + 4) | Should -Be ($percentB.IndexOf('100.0') + 5)
        $percentA.TrimEnd().Length | Should -Be $percentB.TrimEnd().Length

        $hierarchical = @(
            [pscustomobject]@{ Region = 'East'; State = 'NY'; Kind = 'X' }
            [pscustomobject]@{ Region = 'East'; State = 'NY'; Kind = 'Y' }
            [pscustomobject]@{ Region = 'West'; State = 'CA'; Kind = 'X' }
        ) | ConvertTo-PSDataFrame
        $report = $hierarchical | Crosstab -Index Region, State -Columns Kind -Normalize Index -Percent -Outline -Grid
        $report.Metadata.Pivot.Layout | Should -Be 'Outline'
        $report.Metadata.Pivot.Grid | Should -BeTrue
        $report.Metadata.Pivot.Percent | Should -BeTrue
        $report.Rows[0].X | Should -BeOfType [double]
        ($report | Out-String -Width 200) | Should -Match 'Region / State'
        ($report | Out-String -Width 200) | Should -Match '100.0'
        ($report | Out-String -Width 200) | Should -Not -Match '%'
    }

    It 'preserves null normalized fill cells and rejects ambiguous margins or fill values' {
        $source = @(
            [pscustomobject]@{ Group = 'A'; Kind = 'X' }
            [pscustomobject]@{ Group = 'B'; Kind = 'Y' }
        ) | ConvertTo-PSDataFrame

        $normalized = $source | Crosstab Group Kind -Normalize Index -FillValue $null
        $normalized.Rows[0].Y | Should -Be $null
        $normalized.Rows[0].X | Should -Be 1

        { $source | Crosstab Group Kind -Normalize All -Margins } |
            Should -Throw '*cannot be combined with -Margins*'
        { $source | Crosstab Group Kind -Normalize Index -FillValue 1 } |
            Should -Throw '*only -FillValue 0 or -FillValue $null*'
        { $source | Crosstab Group Kind -Percent } |
            Should -Throw '*requires -Normalize*'
        { $source | Crosstab Group Kind -Normalize Bad } |
            Should -Throw '*Normalize*'

        $percentNull = $source | Crosstab Group Kind -Normalize Index -Percent -FillValue $null
        $percentNull.Rows[0].Y | Should -Be $null
        $percentNull.Rows[0].X | Should -Be 100
    }

    It 'returns a DataFrame and composes through the pipeline' {
        $wide = $pivotFrame | Pivot -Index Region -Columns Channel -Values Revenue -Aggregate Sum
        $wide.PSTypeNames | Should -Contain 'PSPandas.DataFrame'
        ($wide.Columns -join ',') | Should -Be 'Region,Online,Store'
        @($wide.Rows).Count | Should -Be 2
        $wide.Rows[0].Online | Should -Be 25
        $wide.Rows[0].Store | Should -Be 20
        $wide.Rows[1].Online | Should -Be $null
        $wide.Rows[1].Store | Should -Be 30
        ($wide.Rows[0].PSObject.Properties.Name -join ',') | Should -Be ($wide.Columns -join ',')

        $summary = $wide | Summarize -Sum Online, Store
        $summary.Rows[0].Sum_Online | Should -Be 25
        $summary.Rows[0].Sum_Store | Should -Be 50
    }

    It 'supports positional index, columns, and values with Sum by default' {
        $wide = $pivotFrame | Pivot Region Channel Revenue

        ($wide.Columns -join ',') | Should -Be 'Region,Online,Store'
        $wide.Rows[0].Online | Should -Be 25
        $wide.Rows[0].Store | Should -Be 20
        $wide.Rows[1].Store | Should -Be 30
        $wide.Metadata.Pivot.Metrics[0].Function | Should -Be 'Sum'
    }

    It 'uses an implicit Count frequency pivot when Values are omitted' {
        $events = @(
            [pscustomobject]@{ User = 'Alice'; Action = 'Login' }
            [pscustomobject]@{ User = 'Alice'; Action = 'Login' }
            [pscustomobject]@{ User = 'Alice'; Action = 'Logout' }
            [pscustomobject]@{ User = 'Bob'; Action = 'Login' }
            [pscustomobject]@{ User = 'Charlie'; Action = 'Logout' }
        ) | ConvertTo-PSDataFrame

        $wide = $events | Pivot User Action

        ($wide.Columns -join ',') | Should -Be 'User,Login,Logout'
        $wide.Rows[0].User | Should -Be 'Alice'
        $wide.Rows[0].Login | Should -Be 2
        $wide.Rows[0].Logout | Should -Be 1
        $wide.Rows[0].Login | Should -BeOfType [int]
        $wide.Rows[1].User | Should -Be 'Bob'
        $wide.Rows[1].Login | Should -Be 1
        $wide.Rows[1].Logout | Should -Be 0
        $wide.Rows[2].User | Should -Be 'Charlie'
        $wide.Rows[2].Login | Should -Be 0
        $wide.Rows[2].Logout | Should -Be 1
        $wide.Metadata.Pivot.Metrics[0].Function | Should -Be 'Count'
    }

    It 'allows explicit Count without Values and rejects other scalar aggregates' {
        $events = @(
            [pscustomobject]@{ User = 'Alice'; Action = 'Login' }
            [pscustomobject]@{ User = 'Alice'; Action = 'Logout' }
        ) | ConvertTo-PSDataFrame

        $counted = $events | Pivot User Action -Aggregate Count
        $counted.Rows[0].Login | Should -Be 1
        $counted.Rows[0].Login | Should -BeOfType [int]

        { $events | Pivot User Action -Aggregate Sum } |
            Should -Throw '*Specify -Values when using -Aggregate Sum*'
    }

    It 'stores structured mappings for flattened pivot columns' {
        $wide = $pivotFrame | Pivot -Index Region, State -Columns Year, Quarter -Values Revenue -Aggregate Sum
        $wide.Metadata.Pivot.Index | Should -Be @('Region', 'State')
        $wide.Metadata.Pivot.Columns | Should -Be @('Year', 'Quarter')
        $wide.Metadata.Pivot.ColumnMap['2025_Q1'].Property | Should -Be 'Revenue'
        $wide.Metadata.Pivot.ColumnMap['2025_Q1'].Function | Should -Be 'Sum'
        $wide.Metadata.Pivot.ColumnMap['2025_Q1'].ColumnValues | Should -Be @(2025, 'Q1')
    }

    It 'renders a sorted hierarchical outline without changing DataFrame rows' {
        $date1 = [System.DateOnly]::new(2026, 1, 2)
        $date2 = [System.DateOnly]::new(2026, 2, 3)
        $source = @(
            [pscustomobject]@{ Region = 'West'; OrderDate = $date2; Channel = 'Store'; Amount = 5 }
            [pscustomobject]@{ Region = 'East'; OrderDate = $date2; Channel = 'Online'; Amount = 3 }
            [pscustomobject]@{ Region = 'East'; OrderDate = $date1; Channel = 'Store'; Amount = 2 }
        ) | ConvertTo-PSDataFrame

        $plain = $source | Pivot Region, OrderDate Channel Amount -FillValue 0 -Outline
        $plainDisplay = $plain | Out-String -Width 200
        $wide = $source | Pivot Region, OrderDate Channel Amount -FillValue 0 -Outline -Grid
        $display = $wide | Out-String -Width 200

        $wide.Metadata.Pivot.Layout | Should -Be 'Outline'
        $wide.Metadata.Pivot.Grid | Should -BeTrue
        $plain.Metadata.Pivot.Grid | Should -BeFalse
        $plainDisplay | Should -Not -Match '(?m)^┌─+'
        $plainDisplay | Should -Match '(?m)^├── 2026-01-02\s+'
        $wide.PSTypeNames | Should -Contain 'PSPandas.DataFrame'
        @($wide.Rows | ForEach-Object Region) | Should -Be @('East', 'East', 'West')
        $wide.Rows[0].OrderDate.GetType().FullName | Should -Be 'System.DateOnly'
        ($wide.Rows[0].PSObject.Properties.Name -join ',') | Should -Be ($wide.Columns -join ',')
        $display | Should -Match '│ Region / OrderDate\s+│'
        ([regex]::Matches($display, '(?m)^│ East\s+│')).Count | Should -Be 1
        $display | Should -Match '(?m)^│ ├── 2026-01-02\s+│'
        $display | Should -Match '(?m)^│ └── 2026-02-03\s+│'
        $display | Should -Match '(?m)^┌─+┬'
        $display | Should -Match '(?m)^└─+┴.*┘\r?$'

        $borderLines = @($display -split '\r?\n' | Where-Object { $_ -match '^[┌├│╞└]' })
        @($borderLines | ForEach-Object Length | Sort-Object -Unique).Count | Should -Be 1
    }

    It 'renders connecting guides through more than two index levels' {
        $source = @(
            [pscustomobject]@{ Region = 'East'; State = 'NY'; Quarter = 'Q1'; Channel = 'Online'; Revenue = 10 }
            [pscustomobject]@{ Region = 'East'; State = 'NY'; Quarter = 'Q2'; Channel = 'Store'; Revenue = 20 }
            [pscustomobject]@{ Region = 'East'; State = 'PA'; Quarter = 'Q1'; Channel = 'Online'; Revenue = 30 }
            [pscustomobject]@{ Region = 'West'; State = 'CA'; Quarter = 'Q1'; Channel = 'Store'; Revenue = 40 }
        ) | ConvertTo-PSDataFrame
        $wide = $source | Pivot Region, State, Quarter Channel Revenue -FillValue 0 -Outline -Grid
        $display = $wide | Out-String -Width 200

        $display | Should -Match '(?m)^│ East\s+│'
        $display | Should -Match '(?m)^│ ├── NY\s+│'
        $display | Should -Match '(?m)^│ │   ├── Q1\s+│'
        $display | Should -Match '(?m)^│ │   └── Q2\s+│'
        $display | Should -Match '(?m)^│ └── PA\s+│'
        $display | Should -Match '(?m)^│     └── Q1\s+│'
    }
}

Describe 'PSPandas pivot dimensions and aggregate forms' {
    It 'supports multiple indexes, column dimensions, values, and uniform aggregates' {
        $wide = $pivotFrame | Pivot -Index Region, State -Columns Year, Quarter -Values Revenue, Units -Aggregate Sum, Average -FillValue 0

        ($wide.Columns -join ',') | Should -Be (
            'Region,State,' +
            'Sum_Revenue_2025_Q1,Sum_Revenue_2025_Q2,' +
            'Sum_Units_2025_Q1,Sum_Units_2025_Q2,' +
            'Average_Revenue_2025_Q1,Average_Revenue_2025_Q2,' +
            'Average_Units_2025_Q1,Average_Units_2025_Q2'
        )
        $wide.Rows[0].Sum_Revenue_2025_Q1 | Should -Be 25
        $wide.Rows[0].Average_Units_2025_Q1 | Should -Be 1.5
        $wide.Rows[1].Sum_Revenue_2025_Q2 | Should -Be 0
    }

    It 'supports an ordered per-value aggregate map' {
        $wide = $pivotFrame | Pivot -Index Region, State -Columns Year, Quarter -Aggregate ([ordered]@{
            Revenue = 'Sum'
            Units   = @('Sum', 'Average')
            OrderId = 'Count'
        }) -FillValue 0

        ($wide.Columns -join ',') | Should -Be (
            'Region,State,' +
            'Sum_Revenue_2025_Q1,Sum_Revenue_2025_Q2,' +
            'Sum_Units_2025_Q1,Sum_Units_2025_Q2,' +
            'Average_Units_2025_Q1,Average_Units_2025_Q2,' +
            'Count_OrderId_2025_Q1,Count_OrderId_2025_Q2'
        )
        $wide.Rows[0].Count_OrderId_2025_Q1 | Should -Be 2
        $wide.Rows[0].Average_Units_2025_Q2 | Should -Be 4
        $wide.Rows[1].Count_OrderId_2025_Q2 | Should -Be 0
    }

    It 'supports advanced named and scriptblock aggregates' {
        $wide = $pivotFrame | Pivot -Index Region -Columns Channel -Aggregate ([ordered]@{
            TotalRevenue = @{ Property = 'Revenue'; Function = 'Sum' }
            PeakRevenue  = @{ Property = 'Revenue'; Function = 'Max' }
            SourceRows   = { param($rows) @($rows).Count }
        }) -FillValue 0

        ($wide.Columns -join ',') | Should -Be (
            'Region,' +
            'TotalRevenue_Online,TotalRevenue_Store,' +
            'PeakRevenue_Online,PeakRevenue_Store,' +
            'SourceRows_Online,SourceRows_Store'
        )
        $wide.Rows[0].TotalRevenue_Online | Should -Be 25
        $wide.Rows[0].PeakRevenue_Online | Should -Be 15
        $wide.Rows[0].SourceRows_Online | Should -Be 2
    }

    It 'supports a pivot without index columns' {
        $wide = $pivotFrame | Pivot -Columns Quarter -Values Revenue -Aggregate Sum
        @($wide.Rows).Count | Should -Be 1
        ($wide.Columns -join ',') | Should -Be 'Q1,Q2'
        $wide.Rows[0].Q1 | Should -Be 55
        $wide.Rows[0].Q2 | Should -Be 20
    }
}

Describe 'PSPandas pivot cell and ordering semantics' {
    It 'enforces uniqueness when Unique is requested' {
        $unique = @(
            [pscustomobject]@{ Region = 'East'; Channel = 'Online'; Manager = 'Lee' }
            [pscustomobject]@{ Region = 'East'; Channel = 'Store'; Manager = 'Pat' }
        ) | ConvertTo-PSDataFrame
        $wide = $unique | Pivot -Index Region -Columns Channel -Values Manager -Unique
        $wide.Rows[0].Online | Should -Be 'Lee'
        $wide.Rows[0].Store | Should -Be 'Pat'

        { $pivotFrame | Pivot -Index Region -Columns Channel -Values Revenue -Unique } |
            Should -Throw '*not unique*Remove -Unique*'
    }

    It 'fills absent cells but does not replace an existing null aggregate result' {
        $withNull = @(
            [pscustomobject]@{ Region = 'East'; Channel = 'Online'; Amount = $null }
            [pscustomobject]@{ Region = 'West'; Channel = 'Store'; Amount = 3 }
        ) | ConvertTo-PSDataFrame
        $wide = $withNull | Pivot -Index Region -Columns Channel -Values Amount -Aggregate Average -FillValue 0

        $wide.Rows[0].Online | Should -Be $null
        $wide.Rows[0].Store | Should -Be 0
        $wide.Rows[1].Online | Should -Be 0
        $wide.Rows[1].Store | Should -Be 3
    }

    It 'preserves first-seen order by default and can sort both axes' {
        $unordered = @(
            [pscustomobject]@{ Region = 'West'; Channel = 'Store'; Amount = 1 }
            [pscustomobject]@{ Region = 'East'; Channel = 'Online'; Amount = 2 }
        ) | ConvertTo-PSDataFrame

        $firstSeen = $unordered | Pivot -Index Region -Columns Channel -Values Amount -Aggregate Sum
        ($firstSeen.Columns -join ',') | Should -Be 'Region,Store,Online'
        @($firstSeen.Rows | ForEach-Object Region) | Should -Be @('West', 'East')

        $sorted = $unordered | Pivot -Index Region -Columns Channel -Values Amount -Aggregate Sum -Sort
        ($sorted.Columns -join ',') | Should -Be 'Region,Online,Store'
        @($sorted.Rows | ForEach-Object Region) | Should -Be @('East', 'West')
    }

    It 'uses deterministic labels for typed date and null column values' {
        $dateOnly = [System.DateOnly]::new(2026, 2, 15)
        $typed = @(
            [pscustomobject]@{ Region = 'East'; Period = $dateOnly; Amount = 2 }
            [pscustomobject]@{ Region = 'East'; Period = $null; Amount = 3 }
        ) | ConvertTo-PSDataFrame
        $wide = $typed | Pivot -Index Region -Columns Period -Values Amount -Aggregate Sum

        ($wide.Columns -join ',') | Should -Be 'Region,2026-02-15,[null]'
        $wide.Rows[0].'2026-02-15' | Should -Be 2
        $wide.Rows[0].'[null]' | Should -Be 3
    }
}

Describe 'PSPandas pivot margins, empty inputs, and validation' {
    It 'recomputes non-additive margins from source rows' {
        $source = @(
            [pscustomobject]@{ Region = 'East'; Channel = 'Online'; Units = 1 }
            [pscustomobject]@{ Region = 'East'; Channel = 'Online'; Units = 3 }
            [pscustomobject]@{ Region = 'East'; Channel = 'Store'; Units = 100 }
            [pscustomobject]@{ Region = 'West'; Channel = 'Online'; Units = 5 }
        ) | ConvertTo-PSDataFrame
        $wide = $source | Pivot -Index Region -Columns Channel -Values Units -Aggregate Average -Margins -MarginsName All

        ($wide.Columns -join ',') | Should -Be 'Region,Online,Store,All'
        $wide.Rows[0].Online | Should -Be 2
        $wide.Rows[0].Store | Should -Be 100
        $wide.Rows[0].All | Should -Be (104 / 3)
        $wide.Rows[1].All | Should -Be 5
        $wide.Rows[2].Region | Should -Be 'All'
        $wide.Rows[2].Online | Should -Be 3
        $wide.Rows[2].Store | Should -Be 100
        $wide.Rows[2].All | Should -Be (109 / 4)
    }

    It 'preserves a useful schema for an empty frame' {
        $empty = ConvertTo-PSDataFrame -Columns Region, Channel, Amount
        $wide = $empty | Pivot -Index Region -Columns Channel -Values Amount -Aggregate Sum

        $wide.PSTypeNames | Should -Contain 'PSPandas.DataFrame'
        $wide.Count | Should -Be 0
        ($wide.Columns -join ',') | Should -Be 'Region'
        $wide.Metadata.Pivot.Metrics[0].Property | Should -Be 'Amount'
    }

    It 'rejects ambiguous or invalid requests clearly' {
        { $pivotFrame | Pivot -Index Region -Columns Region -Values Revenue -Aggregate Sum } |
            Should -Throw '*duplicated or used in both*'
        { $pivotFrame | Pivot -Index Region -Columns Missing -Values Revenue -Aggregate Sum } |
            Should -Throw "*Column 'Missing' does not exist*"
        { $pivotFrame | Pivot -Index Region -Columns Channel -Values Missing -Aggregate Sum } |
            Should -Throw "*Column 'Missing' does not exist*"
        { $pivotFrame | Pivot -Index Region -Columns Channel -Values Revenue -Aggregate Median } |
            Should -Throw '*Unsupported aggregate function*'
        { $pivotFrame | Pivot -Index Region -Columns Channel -Values Revenue -Aggregate ([ordered]@{ Revenue = 'Sum' }) } |
            Should -Throw '*Do not combine -Values with a dictionary*'
        { $pivotFrame | Pivot -Index Region -Columns Channel -Values Revenue -Unique -Margins } |
            Should -Throw '*Margins requires -Aggregate*'
        { $pivotFrame | Pivot -Index Region -Columns Channel -Values Revenue -Unique -Aggregate Sum } |
            Should -Throw '*Unique cannot be combined*Aggregate*'
        { $pivotFrame | Pivot -Index Region -Columns Channel -Values Revenue -Outline } |
            Should -Throw '*Outline requires at least two*Index*'
        { $pivotFrame | Pivot -Index Region, State -Columns Channel -Values Revenue -Grid } |
            Should -Throw '*Grid requires -Outline*'
    }

    It 'detects flattened-name and margin collisions' {
        $collision = @(
            [pscustomobject]@{ Region = 'East'; A = 'x_y'; B = 'z'; Amount = 1 }
            [pscustomobject]@{ Region = 'East'; A = 'x'; B = 'y_z'; Amount = 2 }
        ) | ConvertTo-PSDataFrame
        { $collision | Pivot -Index Region -Columns A, B -Values Amount -Aggregate Sum } |
            Should -Throw '*same label*'

        $marginCollision = @(
            [pscustomobject]@{ Region = 'East'; Channel = 'Total'; Amount = 1 }
        ) | ConvertTo-PSDataFrame
        { $marginCollision | Pivot -Index Region -Columns Channel -Values Amount -Aggregate Sum -Margins } |
            Should -Throw '*Margins name*collides*'
    }
}
