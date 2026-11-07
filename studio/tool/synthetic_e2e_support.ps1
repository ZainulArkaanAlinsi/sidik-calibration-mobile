Set-StrictMode -Version 2.0

function Get-SidikFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path.Length -lt 3 -or $Path.Substring(0, 2) -notmatch '^[A-Za-z]:$' -or
        ($Path[2] -ne [IO.Path]::DirectorySeparatorChar -and
         $Path[2] -ne [IO.Path]::AltDirectorySeparatorChar)) {
        throw 'A local, fully qualified drive path is required.'
    }
    $full = [IO.Path]::GetFullPath($Path)
    if ($full -eq [IO.Path]::GetPathRoot($full)) { return $full }
    return $full.TrimEnd([char[]]'\/')
}

function Assert-SidikNoReparseAncestor {
    param([Parameter(Mandatory = $true)][string]$Path)
    $candidate = Get-SidikFullPath $Path
    while ($candidate) {
        if (Test-Path -LiteralPath $candidate) {
            $item = Get-Item -LiteralPath $candidate -Force -ErrorAction Stop
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw 'Reparse points are not allowed in an E2E path.'
            }
        }
        $parent = [IO.Path]::GetDirectoryName($candidate)
        if ($parent -eq $candidate) { break }
        $candidate = $parent
    }
}

function Assert-SidikChildPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )
    $full = Get-SidikFullPath $Path
    $boundary = (Get-SidikFullPath $Root) + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The E2E path must be strictly inside its owned root.'
    }
    Assert-SidikNoReparseAncestor $full
    return $full
}

function Assert-SidikLoopbackUrl {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][int]$Port
    )
    $uri = $null
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne 'http' -or $uri.Host -cne '127.0.0.1' -or
        $uri.Port -ne $Port -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or
        $uri.AbsolutePath -cne '/api') {
        throw 'Only the exact HTTP loopback API address is allowed.'
    }
    return $uri
}

function Assert-SidikMarker {
    param(
        [Parameter(Mandatory = $true)]$Marker,
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$ManifestHash
    )
    if ($Marker.schema_version -ne 1 -or $Marker.run_id -cne $Manifest.run_id -or
        $Marker.api_sha -cne $Manifest.api_sha -or $Marker.mobile_sha -cne $Manifest.mobile_sha -or
        $Marker.app_env -cne 'testing' -or $Marker.db_driver -cne 'sqlite' -or
        $Marker.manifest_sha256 -cne $ManifestHash.ToLowerInvariant()) {
        throw 'The E2E server identity does not match this run.'
    }
}

function Get-SidikCleanGitHead {
    param([Parameter(Mandatory = $true)][string]$Repository)
    Assert-SidikNoReparseAncestor $Repository
    $head = & git -C $Repository rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or $head -notmatch '^[a-f0-9]{40}$') {
        throw 'Cannot resolve the E2E source commit.'
    }
    $changes = & git -C $Repository status --porcelain --untracked-files=normal
    if ($LASTEXITCODE -ne 0 -or $changes) {
        throw 'Commit or isolate the E2E sources before running the harness.'
    }
    return $head.Trim()
}

function ConvertTo-SidikProcessArgument {
    param([Parameter(Mandatory = $true)][string]$Value)
    if ($Value.Contains('"') -or $Value.Contains("`r") -or $Value.Contains("`n")) {
        throw 'Unexpected characters in a process argument.'
    }
    # Owned paths have no trailing separator; no credential is passed as an argument.
    return '"' + $Value + '"'
}

function Invoke-SidikPhpTask {
    param(
        [Parameter(Mandatory = $true)][string]$Php,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$RunRoot,
        [Parameter(Mandatory = $true)][ValidateSet('seed','verify')][string]$Name
    )
    $stdout = Assert-SidikChildPath (Join-Path $RunRoot "$Name-stdout.json") $RunRoot
    $stderr = Assert-SidikChildPath (Join-Path $RunRoot "$Name-stderr.json") $RunRoot
    $quoted = @($Arguments | ForEach-Object { ConvertTo-SidikProcessArgument $_ })
    $child = $null
    try {
        # Capture both streams without PowerShell converting stderr into a truncated error record.
        $child = Start-Process -FilePath $Php -ArgumentList ($quoted -join ' ') -WindowStyle Hidden `
            -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
        # Retain the native handle before a short task exits (Windows PowerShell 5).
        $null = $child.Handle
        $child.WaitForExit()
        $child.Refresh()
        if ($child.ExitCode -ne 0) {
            $safeCode = 'see_private_stderr'
            try {
                $failure = Get-Content -LiteralPath $stderr -Raw | ConvertFrom-Json
                if ([string]$failure.code -match '^[A-Za-z0-9_]{1,100}$') { $safeCode = [string]$failure.code }
            } catch { }
            throw "Synthetic PHP $Name failed: $safeCode. Private diagnostic files are retained."
        }
        $result = Get-Content -LiteralPath $stdout -Raw | ConvertFrom-Json
        $expectedStatus = if ($Name -eq 'seed') { 'seeded' } else { 'verified' }
        if ($null -eq $result -or $result.status -cne $expectedStatus) {
            throw 'The PHP task did not return its required completion status.'
        }
        return $result
    } finally {
        if ($child) {
            $child.Refresh()
            if (-not $child.HasExited) { $child.Kill(); $child.WaitForExit(5000) | Out-Null }
            $child.Dispose()
        }
    }
}
