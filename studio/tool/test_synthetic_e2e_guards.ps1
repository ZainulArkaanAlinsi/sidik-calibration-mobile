$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'synthetic_e2e_support.ps1')
$passed = 0

function Expect-Rejected {
    param([string]$Name, [scriptblock]$Action)
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw "Guard did not reject: $Name" }
    $script:passed++
}

$owned = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'sidik-e2e-sintetis'
$child = Join-Path $owned 'synthetic-guard-example\studio-synthetic.sqlite'
$null = Assert-SidikChildPath $child $owned
$passed++
Expect-Rejected 'relative path' { Get-SidikFullPath '.\studio.sqlite' }
Expect-Rejected 'drive-relative path' { Get-SidikFullPath 'C:studio.sqlite' }
Expect-Rejected 'UNC path' { Get-SidikFullPath '\\example.test\share\studio.sqlite' }
Expect-Rejected 'root itself' { Assert-SidikChildPath $owned $owned }
Expect-Rejected 'sibling prefix' { Assert-SidikChildPath ($owned + '-other\studio.sqlite') $owned }
Expect-Rejected 'parent traversal' { Assert-SidikChildPath (Join-Path $owned '..\studio.sqlite') $owned }
$null = Assert-SidikLoopbackUrl 'http://127.0.0.1:12971/api' 12971
$passed++
foreach ($url in @(
    'https://127.0.0.1:12971/api', 'http://localhost:12971/api',
    'http://example.test:12971/api', 'http://127.0.0.1:12972/api',
    'http://user@127.0.0.1:12971/api', 'http://127.0.0.1:12971/api?token=test',
    'http://127.0.0.1:12971/api#fragment', 'http://127.0.0.1:12971/other'
)) {
    Expect-Rejected 'non-owned endpoint' { Assert-SidikLoopbackUrl $url 12971 }
}

$manifest = [pscustomobject]@{run_id='synthetic-run'; api_sha=('a' * 40); mobile_sha=('b' * 40)}
$hash = 'c' * 64
$marker = [pscustomobject]@{
    schema_version=1; run_id=$manifest.run_id; api_sha=$manifest.api_sha
    mobile_sha=$manifest.mobile_sha; app_env='testing'; db_driver='sqlite'; manifest_sha256=$hash
}
Assert-SidikMarker $marker $manifest $hash
$passed++
foreach ($property in @('run_id','api_sha','mobile_sha','app_env','db_driver','manifest_sha256')) {
    $original = $marker.$property
    $marker.$property = 'wrong'
    Expect-Rejected 'server identity mismatch' { Assert-SidikMarker $marker $manifest $hash }
    $marker.$property = $original
}
Expect-Rejected 'quoted process argument' { ConvertTo-SidikProcessArgument 'a"b' }
Expect-Rejected 'newline process argument' { ConvertTo-SidikProcessArgument "a`nb" }

# A real junction in the repository's ignored build directory exercises the ancestor check.
$studio = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$build = Join-Path $studio 'build'
$fixtureRoot = Assert-SidikChildPath (Join-Path $build ('guard-' + [Guid]::NewGuid().ToString('N'))) $build
$target = Join-Path $fixtureRoot 'target'
$junction = Join-Path $fixtureRoot 'junction'
try {
    [IO.Directory]::CreateDirectory($target) | Out-Null
    Set-Content -LiteralPath (Join-Path $target 'owned-marker.txt') -Value 'synthetic guard fixture'
    New-Item -ItemType Junction -Path $junction -Target $target -ErrorAction Stop | Out-Null
    Expect-Rejected 'existing junction ancestor' { Assert-SidikNoReparseAncestor (Join-Path $junction 'new.sqlite') }
} finally {
    if (Test-Path -LiteralPath $junction) {
        # Nonrecursive unlink; never traverse the junction's target.
        [IO.Directory]::Delete($junction, $false)
    }
    if (-not (Test-Path -LiteralPath $target)) { throw 'Junction cleanup changed its target.' }
    $null = Assert-SidikChildPath $fixtureRoot $build
    Assert-SidikNoReparseAncestor $fixtureRoot
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
}
Write-Output "Synthetic runner guards: $passed passed. No server or database was opened."
