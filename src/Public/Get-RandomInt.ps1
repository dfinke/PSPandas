function Get-RandomInt {
    <#
    .SYNOPSIS
    Generates random integer values.

    .DESCRIPTION
    Returns uniformly distributed Int32 values in the range from Minimum,
    inclusive, to Maximum, exclusive. The values are emitted individually so
    they compose naturally with PowerShell pipelines.

    .PARAMETER Count
    Number of values to generate. Defaults to one value.

    .PARAMETER Minimum
    Inclusive lower bound. Defaults to zero.

    .PARAMETER Maximum
    Exclusive upper bound. Defaults to Int32.MaxValue.

    .PARAMETER Seed
    Optional seed for repeatable sequences, which is useful for examples and
    tests. Omit it for a non-deterministically seeded generator.

    .EXAMPLE
    Get-RandomInt -Count 12 -Minimum 1 -Maximum 101

    Generates twelve integers from 1 through 100.

    .EXAMPLE
    Get-RandomInt -Count 3 -Minimum 10 -Maximum 20 -Seed 42

    Generates a repeatable sequence of integers from 10 through 19.

    .OUTPUTS
    System.Int32
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateRange(1, 1000000)]
        [int]$Count = 1,

        [Parameter()]
        [int]$Minimum = 0,

        [Parameter()]
        [int]$Maximum = [int]::MaxValue,

        [Parameter()]
        [int]$Seed
    )

    if ($Maximum -le $Minimum) {
        throw "Maximum must be greater than Minimum. Maximum is exclusive."
    }

    $random = if ($PSBoundParameters.ContainsKey('Seed')) {
        [System.Random]::new($Seed)
    } else {
        [System.Random]::new()
    }

    for ($index = 0; $index -lt $Count; $index++) {
        [int]$random.Next($Minimum, $Maximum)
    }
}
