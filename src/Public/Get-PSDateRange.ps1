function Get-PSDateRange {
    <#
    .SYNOPSIS
    Generates a regular sequence of dates or timestamps.

    .DESCRIPTION
    Generates a pipeline-friendly date sequence similar to pandas date_range.
    Provide exactly two of Start, End, and Periods. When both Start and End
    are supplied, Inclusive controls whether the endpoints are returned.
    Periods-based ranges always contain exactly the requested number of values.

    Supported frequencies are Day (D), Hour (h), Week (W), BusinessDay (B),
    MonthStart (MS), MonthEnd (ME), QuarterStart (QS), and YearStart (YS).
    Frequencies are case-insensitive except for the documented short names.

    .PARAMETER Start
    Starting date or timestamp.

    .PARAMETER End
    Ending date or timestamp.

    .PARAMETER Periods
    Number of values to generate. Use with Start or End.

    .PARAMETER Frequency
    Interval used to advance the range. Defaults to Day.

    .PARAMETER Inclusive
    Endpoint behavior when both Start and End are supplied. Valid values are
    Both, Left, Right, and Neither. Defaults to Both.

    .PARAMETER DateOnly
    Returns System.DateOnly values instead of System.DateTime values.

    .EXAMPLE
    Get-PSDateRange -Start '2024-01-01' -End '2024-01-10'

    Generates one DateTime value for each day, including both endpoints.

    .EXAMPLE
    Get-PSDateRange -Start '2024-01-01' -Periods 12 -Frequency MonthStart -DateOnly

    Generates twelve DateOnly values representing month starts.

    .EXAMPLE
    Get-PSDateRange -End '2024-01-05' -Periods 5 -Frequency BusinessDay

    Generates the five business days ending at the supplied date.

    .OUTPUTS
    System.DateTime
    System.DateOnly when -DateOnly is specified.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [datetime]$Start,

        [Parameter()]
        [datetime]$End,

        [Parameter()]
        [ValidateRange(1, 1000000)]
        [int]$Periods,

        [Parameter()]
        [ValidateSet('Day', 'D', 'Hour', 'h', 'Week', 'W', 'BusinessDay', 'B', 'MonthStart', 'MS', 'MonthEnd', 'ME', 'QuarterStart', 'QS', 'YearStart', 'YS')]
        [string]$Frequency = 'Day',

        [Parameter()]
        [ValidateSet('Both', 'Left', 'Right', 'Neither')]
        [string]$Inclusive = 'Both',

        [Parameter()]
        [switch]$DateOnly
    )

    $hasStart = $PSBoundParameters.ContainsKey('Start')
    $hasEnd = $PSBoundParameters.ContainsKey('End')
    $hasPeriods = $PSBoundParameters.ContainsKey('Periods')
    $argumentCount = @(@($hasStart, $hasEnd, $hasPeriods) | Where-Object { $_ }).Count

    if ($argumentCount -ne 2) {
        throw 'Provide exactly two of -Start, -End, and -Periods.'
    }

    if ($hasPeriods -and $Inclusive -ne 'Both') {
        throw '-Inclusive applies only when both -Start and -End are supplied.'
    }

    $frequencyKey = switch -Regex ($Frequency) {
        '^(Day|D)$' { 'Day'; break }
        '^(Hour|h)$' { 'Hour'; break }
        '^(Week|W)$' { 'Week'; break }
        '^(BusinessDay|B)$' { 'BusinessDay'; break }
        '^(MonthStart|MS)$' { 'MonthStart'; break }
        '^(MonthEnd|ME)$' { 'MonthEnd'; break }
        '^(QuarterStart|QS)$' { 'QuarterStart'; break }
        '^(YearStart|YS)$' { 'YearStart'; break }
    }

    $normalize = {
        param([datetime]$Value, [int]$Direction)

        switch ($frequencyKey) {
            'BusinessDay' {
                while ($Value.DayOfWeek -eq [DayOfWeek]::Saturday -or $Value.DayOfWeek -eq [DayOfWeek]::Sunday) {
                    $Value = $Value.AddDays($Direction)
                }
                return $Value
            }
            'MonthStart' { return [datetime]::new($Value.Year, $Value.Month, 1, 0, 0, 0, $Value.Kind) }
            'MonthEnd' { return [datetime]::new($Value.Year, $Value.Month, [datetime]::DaysInMonth($Value.Year, $Value.Month), 0, 0, 0, $Value.Kind) }
            'QuarterStart' {
                $month = ([math]::Floor(($Value.Month - 1) / 3) * 3) + 1
                return [datetime]::new($Value.Year, [int]$month, 1, 0, 0, 0, $Value.Kind)
            }
            'YearStart' { return [datetime]::new($Value.Year, 1, 1, 0, 0, 0, $Value.Kind) }
            default { return $Value }
        }
    }

    $step = {
        param([datetime]$Value, [int]$Direction)

        switch ($frequencyKey) {
            'Day' { return $Value.AddDays($Direction) }
            'Hour' { return $Value.AddHours($Direction) }
            'Week' { return $Value.AddDays(7 * $Direction) }
            'BusinessDay' {
                do { $Value = $Value.AddDays($Direction) }
                while ($Value.DayOfWeek -eq [DayOfWeek]::Saturday -or $Value.DayOfWeek -eq [DayOfWeek]::Sunday)
                return $Value
            }
            'MonthStart' { return [datetime]::new($Value.AddMonths($Direction).Year, $Value.AddMonths($Direction).Month, 1, 0, 0, 0, $Value.Kind) }
            'MonthEnd' {
                $next = $Value.AddMonths($Direction)
                return [datetime]::new($next.Year, $next.Month, [datetime]::DaysInMonth($next.Year, $next.Month), 0, 0, 0, $Value.Kind)
            }
            'QuarterStart' {
                $next = $Value.AddMonths(3 * $Direction)
                $month = ([math]::Floor(($next.Month - 1) / 3) * 3) + 1
                return [datetime]::new($next.Year, [int]$month, 1, 0, 0, 0, $Value.Kind)
            }
            'YearStart' { return [datetime]::new($Value.Year + $Direction, 1, 1, 0, 0, 0, $Value.Kind) }
        }
    }

    $values = [System.Collections.Generic.List[datetime]]::new()

    if ($hasStart -and $hasEnd) {
        $current = & $normalize $Start 1
        $target = & $normalize $End -1
        if ($current -le $target) {
            while ($current -le $target) {
                $isFirst = $current -eq (& $normalize $Start 1)
                $isLast = $current -eq (& $normalize $End -1)
                $includeCurrent = (-not $isFirst -or $Inclusive -in @('Both', 'Left')) -and
                    (-not $isLast -or $Inclusive -in @('Both', 'Right'))
                if ($includeCurrent) { $values.Add($current) }
                $current = & $step $current 1
            }
        }
    } elseif ($hasStart) {
        $current = & $normalize $Start 1
        for ($index = 0; $index -lt $Periods; $index++) {
            $values.Add($current)
            $current = & $step $current 1
        }
    } else {
        $current = & $normalize $End -1
        for ($index = 0; $index -lt $Periods; $index++) {
            $values.Insert(0, $current)
            $current = & $step $current -1
        }
    }

    foreach ($value in $values) {
        if ($DateOnly) {
            [System.DateOnly]::new($value.Year, $value.Month, $value.Day)
        } else {
            $value
        }
    }
}
