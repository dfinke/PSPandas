Import-Module (Join-Path $PSScriptRoot '..\PSPandas.psd1') -Force

$orders = @(
    [pscustomobject][ordered]@{ OrderId = 5001; OrderDate = [datetime]'2024-01-15'; State = 'CA'; Amount = [decimal]125.50 }
    [pscustomobject][ordered]@{ OrderId = 5002; OrderDate = [datetime]'2024-02-03'; State = 'NY'; Amount = [decimal]89.25 }
    [pscustomobject][ordered]@{ OrderId = 5003; OrderDate = [datetime]'2024-06-21'; State = 'CA'; Amount = [decimal]210.00 }
    [pscustomobject][ordered]@{ OrderId = 5004; OrderDate = [datetime]'2024-09-08'; State = 'TX'; Amount = [decimal]74.75 }
    [pscustomobject][ordered]@{ OrderId = 5005; OrderDate = [datetime]'2025-01-12'; State = 'NY'; Amount = [decimal]145.00 }
    [pscustomobject][ordered]@{ OrderId = 5006; OrderDate = [datetime]'2025-03-27'; State = 'CA'; Amount = [decimal]310.50 }
    [pscustomobject][ordered]@{ OrderId = 5007; OrderDate = [datetime]'2025-07-19'; State = 'TX'; Amount = [decimal]98.00 }
    [pscustomobject][ordered]@{ OrderId = 5008; OrderDate = [datetime]'2025-11-04'; State = 'NY'; Amount = [decimal]175.25 }
) | ConvertTo-PSDataFrame

'Total sales amount:'
'{0:C2}' -f $orders['Amount'].Sum()

'Sales by state, sorted by revenue:'
$orders |
    Summarize -By State -Count OrderId -Sum Amount |
    Set-PSDataFrameOrder -Property Sum_Amount -Descending |
    ConvertFrom-PSDataFrame |
    Format-Table

'Year and state trend:'
$orders |
    Add-PSDataFrameColumn -Name Year -Expression { $_.OrderDate.Year } |
    Summarize -By Year, State -Count OrderId -Sum Amount |
    ConvertFrom-PSDataFrame |
    Format-Table
