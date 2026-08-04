Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$orders = @(
    [pscustomobject][ordered]@{ OrderId = 5001; OrderDate = [datetime]'2025-01-15'; State = 'CA'; Amount = [decimal]125.50; Status = 'Open' }
    [pscustomobject][ordered]@{ OrderId = 5002; OrderDate = [datetime]'2025-02-03'; State = 'NY'; Amount = [decimal]89.25; Status = 'Closed' }
    [pscustomobject][ordered]@{ OrderId = 5003; OrderDate = [datetime]'2025-06-21'; State = 'CA'; Amount = [decimal]210.00; Status = 'Open' }
    [pscustomobject][ordered]@{ OrderId = 5004; OrderDate = [datetime]'2025-09-08'; State = 'TX'; Amount = [decimal]74.75; Status = $null }
) | ConvertTo-PSDataFrame

'Data-frame profile:'
$orders |
    Describe -SampleCount 2
