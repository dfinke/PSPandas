<#
.SYNOPSIS
Verifies that the runnable PSPandas tutorial remains executable.
#>

Describe 'Pandas for PowerShell tutorial' {
    It 'runs the complete companion example' {
        $scriptPath = Join-Path $PSScriptRoot '..\examples\PandasForPowerShell.ps1'
        $completed = $true
        try {
            & $scriptPath *> $null
        } catch {
            $completed = $false
        }

        $completed | Should -BeTrue
    }
}
