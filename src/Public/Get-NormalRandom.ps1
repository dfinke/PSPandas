function Get-NormalRandom {
    <#
    .SYNOPSIS
    Generates random values from a standard normal distribution.

    .DESCRIPTION
    Returns values generated with mean 0 and standard deviation 1, equivalent
    to NumPy's numpy.random.randn(count). The values are emitted individually
    so they compose naturally with PowerShell pipelines.

    .PARAMETER Count
    Number of values to generate. Defaults to one value.

    .PARAMETER Seed
    Optional seed for repeatable sequences, which is useful for examples and
    tests. Omit it for a non-deterministically seeded generator.

    .EXAMPLE
    Get-NormalRandom -Count 12

    Generates twelve standard-normal random values.

    .EXAMPLE
    Get-NormalRandom -Count 3 -Seed 42

    Generates a repeatable sequence of three values.

    .OUTPUTS
    System.Double

    .NOTES
    Uses the Box-Muller transform over System.Random uniform values.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateRange(1, 1000000)]
        [int]$Count = 1,

        [Parameter()]
        [int]$Seed
    )

    $random = if ($PSBoundParameters.ContainsKey('Seed')) {
        [System.Random]::new($Seed)
    } else {
        [System.Random]::new()
    }

    for ($index = 0; $index -lt $Count; $index++) {
        # Keep u1 in the open interval (0, 1) so Log never receives zero.
        $u1 = 1.0 - $random.NextDouble()
        $u2 = $random.NextDouble()

        [double]([math]::Sqrt(-2.0 * [math]::Log($u1)) *
            [math]::Cos(2.0 * [math]::PI * $u2))
    }
}
