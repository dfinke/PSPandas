function Resolve-PSPandasDownloadUri {
    <#
    .SYNOPSIS
    Resolves a supported source URI before download.

    .DESCRIPTION
    Translates the standard github.com owner/repository/blob/branch/path URL
    shape to the corresponding raw.githubusercontent.com URL. Other HTTP and
    HTTPS URIs are returned unchanged.

    .PARAMETER Uri
    Absolute HTTP or HTTPS source URI.

    .OUTPUTS
    System.Uri
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][uri]$Uri)

    if ($Uri.Host -ieq 'github.com') {
        $segments = @($Uri.AbsolutePath.Trim('/').Split('/') | Where-Object { $_ })
        if ($segments.Count -ge 5 -and $segments[2] -ieq 'blob') {
            $rawPath = ($segments[0..1] + $segments[3..($segments.Count - 1)]) -join '/'
            $rawUri = "https://raw.githubusercontent.com/$rawPath"
            if (-not [string]::IsNullOrWhiteSpace($Uri.Query)) { $rawUri += $Uri.Query }
            return [uri]$rawUri
        }
    }

    $Uri
}

function Save-PSPandasUriToTemporaryFile {
    <#
    .SYNOPSIS
    Downloads an HTTP or HTTPS data source to a temporary file.

    .DESCRIPTION
    Preserves the response bytes so both native delimited readers and the
    optional ImportExcel reader can process URI sources through their existing
    local-file paths. The caller owns cleanup of the returned temporary file.

    .PARAMETER Uri
    Absolute HTTP or HTTPS URI to download.

    .PARAMETER TimeoutSec
    Maximum number of seconds allowed for the HTTP request.

    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][uri]$Uri,
        [ValidateRange(1, 600)][int]$TimeoutSec = 30
    )

    if (-not $Uri.IsAbsoluteUri -or $Uri.Scheme -notin @('http', 'https')) {
        throw "PSPandas URI input supports only absolute http:// and https:// URIs; supplied '$Uri'."
    }

    $downloadUri = Resolve-PSPandasDownloadUri -Uri $Uri
    Write-PSPandasProgress -Enabled -Activity 'PSPandas URI download' -Status "Downloading $downloadUri" -PercentComplete 5 -Id 2
    try {
        $response = Invoke-WebRequest -Uri $downloadUri -TimeoutSec $TimeoutSec -ErrorAction Stop
    } catch {
        throw "PSPandas could not download URI '$Uri' (requested as '$downloadUri'): $($_.Exception.Message)"
    }
    Write-PSPandasProgress -Enabled -Activity 'PSPandas URI download' -Status 'Download complete; validating response' -PercentComplete 70 -Id 2

    $contentType = [string]$response.Headers['Content-Type']
    $responseText = [string]$response.Content
    $isHtml = $contentType -match '(?i)(text/html|application/xhtml\+xml)' -or
        $responseText -match '(?is)^\s*<(?:!doctype\s+html|html(?:\s|>))'
    if ($isHtml) {
        if ($null -ne $response.RawContentStream) { $response.RawContentStream.Dispose() }
        throw "PSPandas received an HTML page from URI '$Uri' instead of a data file. Use the raw download URL or a standard GitHub blob URL that points to a data file."
    }

    $extension = [System.IO.Path]::GetExtension($Uri.AbsolutePath).ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($extension)) {
        if ($contentType -match '(?i)(spreadsheetml|excel|ms-excel)') {
            $extension = '.xlsx'
        } elseif ($contentType -match '(?i)(tab-separated|tsv)') {
            $extension = '.tsv'
        } elseif ($contentType -match '(?i)(json)') {
            $extension = '.json'
        } else {
            $extension = '.csv'
        }
    }

    $temporaryPath = Join-Path ([System.IO.Path]::GetTempPath()) ("pspandas-uri-$([System.IO.Path]::GetRandomFileName())$extension")
    $outputStream = $null
    try {
        $outputStream = [System.IO.File]::Open($temporaryPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        if ($null -ne $response.RawContentStream) {
            if ($response.RawContentStream.CanSeek) { $response.RawContentStream.Position = 0 }
            $response.RawContentStream.CopyTo($outputStream)
        } else {
            $text = $responseText
            if ([string]::IsNullOrEmpty($text)) { throw 'The HTTP response contained no content.' }
            $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($text)
            $outputStream.Write($bytes, 0, $bytes.Length)
        }
        $outputStream.Flush()
        Write-PSPandasProgress -Enabled -Activity 'PSPandas URI download' -Status 'URI source ready for import' -PercentComplete 100 -Id 2 -Completed
        return $temporaryPath
    } catch {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        throw "PSPandas could not cache URI '$Uri': $($_.Exception.Message)"
    } finally {
        if ($null -ne $outputStream) { $outputStream.Dispose() }
        if ($null -ne $response.RawContentStream) { $response.RawContentStream.Dispose() }
    }
}
