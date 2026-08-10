<#
.SYNOPSIS
Demonstrates the column-vector values used by ConvertTo-PSDataFrame.

.DESCRIPTION
Defines a compact, pandas-inspired data shape that can be passed to
ConvertTo-PSDataFrame -ColumnData.
#>

$age = 17, 19, 21, 37, 18, 19, 47, 18, 19
$score = 12, 10, 11, 15, 16, 14, 25, 21, 29
$rt = 3.552, 1.624, 6.431, 7.132, 2.925, 4.662, 3.634, 3.635, 5.234
$group = 'test', 'test', 'test', 'test', 'test', 'control', 'control', 'control', 'control'
