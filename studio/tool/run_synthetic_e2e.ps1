<#
Native Studio UI -> real Laravel HTTP -> a new synthetic SQLite database.
This never runs the legacy emulator wrapper or uses the installed Studio session.
Artifacts are retained. No database, directory or old process is deleted.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ApiRepository,
    [Parameter(Mandatory = $true)][string]$PhpExecutable,
    [ValidateRange(1024, 65535)][int]$Port = 12971,
    [switch]$PreflightOnly
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'synthetic_e2e_support.ps1')
$mobileRepository = Get-SidikFullPath (Join-Path $PSScriptRoot '..\..')
$studioDirectory = Join-Path $mobileRepository 'studio'
$apiDirectory = Get-SidikFullPath $ApiRepository
$php = Get-SidikFullPath $PhpExecutable
$server = $null
$serverStarted = $null
$runRoot = $null
$oldLocation = Get-Location

try {
    foreach ($required in @($apiDirectory, $php, (Join-Path $apiDirectory 'vendor\autoload.php'))) {
        Assert-SidikNoReparseAncestor $required
        if (-not (Test-Path -LiteralPath $required)) { throw 'An E2E runtime prerequisite is missing.' }
    }
    foreach ($file in @('bootstrap.php', 'seed.php', 'router.php', 'verify.php')) {
        if (-not (Test-Path -LiteralPath (Join-Path $apiDirectory "tests\Support\StudioE2E\$file"))) {
            throw 'The pinned API checkout does not contain the synthetic harness.'
        }
    }
    $apiSha = Get-SidikCleanGitHead $apiDirectory
    $mobileSha = Get-SidikCleanGitHead $mobileRepository
    $phpVersion = & $php -r 'echo PHP_VERSION;'
    if ($LASTEXITCODE -ne 0 -or $phpVersion.Trim() -cne '8.4.27') {
        throw 'Use the verified PHP 8.4.27 executable.'
    }
    $flutter = (Get-Command flutter -ErrorAction Stop).Source
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
    try { $listener.Start() } finally { $listener.Stop() }
    $runBase = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'sidik-e2e-sintetis'
    Assert-SidikNoReparseAncestor $runBase
    $runId = (Get-Date -Format 'yyyyMMddTHHmmss') + '-' + [Guid]::NewGuid().ToString('N')
    $runRoot = Assert-SidikChildPath (Join-Path $runBase $runId) $runBase
    if (Test-Path -LiteralPath $runRoot) { throw 'The synthetic run directory already exists.' }
    if ($PreflightOnly) {
        Write-Output 'Synthetic E2E preflight passed; no run directory, database or server was created.'
        return
    }

    # Dependency resolution is offline and fatal on lock drift; no SDK installation.
    Set-Location -LiteralPath $mobileRepository
    & $flutter pub get --offline --enforce-lockfile
    if ($LASTEXITCODE -ne 0) { throw 'App dependency lock verification failed.' }
    Set-Location -LiteralPath $studioDirectory
    & $flutter pub get --offline --enforce-lockfile
    if ($LASTEXITCODE -ne 0) { throw 'Studio dependency lock verification failed.' }
    if ((Get-SidikCleanGitHead $apiDirectory) -cne $apiSha -or
        (Get-SidikCleanGitHead $mobileRepository) -cne $mobileSha) {
        throw 'The pinned sources changed during dependency preparation.'
    }

    if (-not (Test-Path -LiteralPath $runBase)) {
        New-Item -ItemType Directory -Path $runBase -ErrorAction Stop | Out-Null
    }
    New-Item -ItemType Directory -Path $runRoot -ErrorAction Stop | Out-Null
    $seed = Join-Path $apiDirectory 'tests\Support\StudioE2E\seed.php'
    $seedResult = Invoke-SidikPhpTask -Php $php -RunRoot $runRoot -Name seed `
        -Arguments @($seed, "--run-root=$runRoot", "--port=$Port", "--mobile-sha=$mobileSha")
    Write-Output 'Synthetic PHP seed completed; identity will be verified before login.'
    $manifestPath = Assert-SidikChildPath (Join-Path $runRoot 'manifest.json') $runRoot
    $definesPath = Assert-SidikChildPath (Join-Path $runRoot 'defines.json') $runRoot
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.schema_version -ne 1 -or $manifest.run_id -cne $runId -or
        $manifest.api_sha -cne $apiSha -or $manifest.mobile_sha -cne $mobileSha) {
        throw 'Synthetic seed identity does not match the pinned sources.'
    }
    $null = Assert-SidikLoopbackUrl $manifest.api_base_url $Port
    $database = Assert-SidikChildPath $manifest.database_path $runRoot
    $expectedDatabase = Get-SidikFullPath (Join-Path $runRoot 'studio-synthetic.sqlite')
    if (-not $database.Equals($expectedDatabase, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The database does not have the expected owned filename.'
    }
    $manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()

    $router = Join-Path $apiDirectory 'tests\Support\StudioE2E\router.php'
    $public = Join-Path $apiDirectory 'public'
    $arguments = @('-S', "127.0.0.1:$Port", '-t', $public, $router) |
        ForEach-Object { ConvertTo-SidikProcessArgument $_ }
    $previousRunRoot = [Environment]::GetEnvironmentVariable('SIDIK_E2E_RUN_ROOT', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('SIDIK_E2E_RUN_ROOT', $runRoot, 'Process')
        $server = Start-Process -FilePath $php -ArgumentList ($arguments -join ' ') -PassThru `
            -WindowStyle Hidden -WorkingDirectory $apiDirectory `
            -RedirectStandardOutput (Join-Path $runRoot 'server-stdout.log') `
            -RedirectStandardError (Join-Path $runRoot 'server-stderr.log')
        $serverStarted = $server.StartTime
    } finally {
        [Environment]::SetEnvironmentVariable('SIDIK_E2E_RUN_ROOT', $previousRunRoot, 'Process')
    }

    $markerReady = $false
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        $server.Refresh()
        if ($server.HasExited) { throw 'The synthetic server exited before the identity check.' }
        try {
            $request = [Net.HttpWebRequest]::Create("http://127.0.0.1:$Port/__sidik_e2e")
            $request.Proxy = $null
            $request.AllowAutoRedirect = $false
            $request.Timeout = 2000
            $response = $request.GetResponse()
        } catch {
            if ($attempt -eq 19) { throw 'The synthetic marker did not become reachable.' }
            Start-Sleep -Milliseconds 250
            continue
        }
        try {
            if ([int]$response.StatusCode -ne 200) { throw 'Unexpected marker HTTP status.' }
            $reader = [IO.StreamReader]::new($response.GetResponseStream())
            try { $marker = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        } finally {
            $response.Dispose()
        }
        Assert-SidikMarker $marker $manifest $manifestHash
        $markerReady = $true
        break
    }
    if (-not $markerReady) { throw 'The synthetic marker was not verified.' }

    $previousParallelism = [Environment]::GetEnvironmentVariable('CMAKE_BUILD_PARALLEL_LEVEL', 'Process')
    $previousNativeErrorPreference = $ErrorActionPreference
    $nativeLog = Join-Path $runRoot 'flutter-e2e.log'
    try {
        [Environment]::SetEnvironmentVariable('CMAKE_BUILD_PARALLEL_LEVEL', '1', 'Process')
        # Windows PowerShell 5 treats even successful native stderr as an error record.
        # Preserve diagnostics, then require the real exit code AND completion artifacts.
        $ErrorActionPreference = 'Continue'
        & $flutter test --no-pub --reporter expanded integration_test/synthetic_smoke_test.dart -d windows `
            "--dart-define-from-file=$definesPath" 2>&1 |
            ForEach-Object { $_.ToString() } |
            Tee-Object -FilePath $nativeLog -ErrorAction Stop
        $testExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousNativeErrorPreference
        [Environment]::SetEnvironmentVariable('CMAKE_BUILD_PARALLEL_LEVEL', $previousParallelism, 'Process')
    }
    if ($testExit -ne 0) { throw 'Native Studio synthetic smoke failed; see the retained run log.' }
    if (-not (Select-String -LiteralPath $nativeLog -SimpleMatch 'All tests passed!' -Quiet)) {
        throw 'The native test completion marker is missing.'
    }
    $pngSignature = @(137,80,78,71,13,10,26,10)
    foreach ($screenshot in @('00-login.png','10-INPUT_SYNTHETIC.png','11-DISPLAY_SYNTHETIC.png','20-logout.png')) {
        $png = Assert-SidikChildPath (Join-Path $runRoot "screenshots\$screenshot") $runRoot
        $bytes = [IO.File]::ReadAllBytes($png)
        if ($bytes.Length -le 8) { throw 'A required native screenshot is empty.' }
        for ($offset = 0; $offset -lt 8; $offset++) {
            if ($bytes[$offset] -ne $pngSignature[$offset]) { throw 'A required screenshot is not PNG.' }
        }
    }
    $verifyResult = Invoke-SidikPhpTask -Php $php -RunRoot $runRoot -Name verify `
        -Arguments @((Join-Path $apiDirectory 'tests\Support\StudioE2E\verify.php'), "--run-root=$runRoot")
    Write-Output "Synthetic Studio HTTP/storage smoke passed. Artifacts: $runRoot"
} finally {
    if ($server) {
        $server.Refresh()
        if (-not $server.HasExited -and $server.StartTime -eq $serverStarted) {
            $server.Kill()
            $server.WaitForExit(5000) | Out-Null
        }
        $server.Dispose()
    }
    Set-Location -LiteralPath $oldLocation.Path
}
