function Write-PSPandasProgress {
    <#
    .SYNOPSIS
    Writes a throttled PSPandas progress update.

    .DESCRIPTION
    Calls Write-Progress when enabled and the effective ProgressPreference
    allows reporting. Updates are throttled so progress does not materially
    slow large inputs.

    .PARAMETER Enabled
    Enables the progress update for an internal operation.

    .PARAMETER Activity
    Activity label shown by Write-Progress.

    .PARAMETER Status
    Current phase or operation status.

    .PARAMETER PercentComplete
    Completion percentage from 0 through 100.

    .PARAMETER Id
    Progress record identifier.

    .PARAMETER Completed
    Completes and removes the progress record.
    #>
    [CmdletBinding()]
    param(
        [switch]$Enabled,
        [Parameter(Mandatory)][string]$Activity,
        [Parameter(Mandatory)][string]$Status,
        [ValidateRange(0, 100)][int]$PercentComplete = 0,
        [int]$Id = 0,
        [switch]$Completed
    )

    if (-not $Enabled -or $ProgressPreference -in @('SilentlyContinue', 'Ignore')) { return }

    $stateVariable = Get-Variable -Name PSPandasProgressState -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $stateVariable -or $stateVariable.Value -isnot [hashtable]) {
        $script:PSPandasProgressState = @{}
    }
    $key = "$Id`:$Activity"
    $now = [DateTime]::UtcNow.Ticks
    $last = if ($script:PSPandasProgressState.ContainsKey($key)) { [int64]$script:PSPandasProgressState[$key] } else { 0L }
    $throttleTicks = [TimeSpan]::FromMilliseconds(150).Ticks
    if (-not $Completed -and $PercentComplete -lt 100 -and $last -gt 0 -and ($now - $last) -lt $throttleTicks) { return }

    if ($Completed) {
        Write-Progress -Id $Id -Activity $Activity -Status $Status -Completed
        [void]$script:PSPandasProgressState.Remove($key)
    } else {
        Write-Progress -Id $Id -Activity $Activity -Status $Status -PercentComplete $PercentComplete
        $script:PSPandasProgressState[$key] = $now
    }
}
