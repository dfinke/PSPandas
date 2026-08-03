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
        (Get-Command Find-PSDataFrame).CommandType | Should -Be 'Function'
        (Get-Command Set-PSDataFrameOrder).CommandType | Should -Be 'Function'
        (Get-Command Measure-PSDataFrame).CommandType | Should -Be 'Function'
        (Get-Command Where-PSDataFrame).CommandType | Should -Be 'Alias'
        (Get-Command Where-PSDataFrame).Definition | Should -Be 'Find-PSDataFrame'
        (Get-Command Sort-PSDataFrame).Definition | Should -Be 'Set-PSDataFrameOrder'
        (Get-Command Summarize-PSDataFrame).Definition | Should -Be 'Measure-PSDataFrame'
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
