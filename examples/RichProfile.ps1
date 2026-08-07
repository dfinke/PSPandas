<#
.SYNOPSIS
Demonstrates profiling a deterministic mixed-type dataset.

.DESCRIPTION
Creates 100 realistic records containing numeric, date, text, Boolean, null,
and mixed-quality values, then displays a structured profile.

.EXAMPLE
& ./examples/RichProfile.ps1
#>

Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$states = @('CA', 'NY', 'TX', 'WA')
$channels = @('Web', 'Store', 'Partner')
$baseDate = [datetime]'2025-01-01T08:00:00'

$records = for ($index = 1; $index -le 100; $index++) {
    $discount = if ($index % 10 -eq 0) { $null } else { [decimal](($index % 5) * 2.5) }
    $qualityNote = if ($index % 17 -eq 0) { $index } else { 'batch-{0:00}' -f (($index - 1) % 12 + 1) }

    [pscustomobject][ordered]@{
        OrderId       = 10000 + $index
        Units         = 1 + ($index % 12)
        Amount        = [decimal](25 + (($index * 37) % 475) + (($index % 4) * 0.25))
        OrderDate     = $baseDate.AddDays($index - 1).AddHours($index % 8)
        State         = $states[($index - 1) % $states.Count]
        Channel       = $channels[($index - 1) % $channels.Count]
        IsPriority    = [bool]($index % 3 -eq 0)
        Discount      = $discount
        QualityNote   = $qualityNote
    }
}

'Rich profile for {0} deterministic mock orders (direct display):' -f @($records).Count
$data = $records | ConvertTo-PSDataFrame
$profile = $data | Describe -SampleCount 3
$profile

'DateTime profile rows via -AsRows:'
$data |
    Describe -SampleCount 3 -AsRows |
    Where-Object Type -eq 'DateTime' |
    Format-Table Column, Type, Minimum, Maximum
