param(
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-Drone-Remote-Control',
    [string]$Tag = 'drone-remote-control-0.2.20-test'
)
$ErrorActionPreference = 'Stop'
if ($Commit -notmatch '^[0-9a-f]{40}$') { throw 'A full pushed source commit is required.' }
if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Invalid repository.' }
$names = @('Drone-Remote-Control-0.2.20-private-test-EN.zip',
           'Drone-Remote-Control-0.2.20-private-test-KO.zip')
$assets = @()
foreach ($name in $names) {
    $path = Join-Path $PSScriptRoot "releases/$name"
    $digest = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    $checksum = $path + '.sha256'
    if ((Get-Content -LiteralPath $checksum -Raw).Trim() -ne "$digest  $name") {
        throw "Checksum file does not match $name."
    }
    foreach ($file in @($path, $checksum)) {
        $assets += [ordered]@{ path = $file; name = [IO.Path]::GetFileName($file);
            sha256 = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant();
            size = (Get-Item -LiteralPath $file).Length }
    }
}
$lines = "protocol=https`nhost=github.com`n`n" | git -c "safe.directory=$PSScriptRoot" credential fill
if ($LASTEXITCODE -ne 0) { throw 'GitHub Git authentication is unavailable.' }
$credential = @{}
foreach ($line in $lines) {
    $parts = $line.Split('=', 2)
    if ($parts.Length -eq 2) { $credential[$parts[0]] = $parts[1] }
}
if (-not $credential.password) { throw 'GitHub Git authentication is unavailable.' }
$headers = @{ Authorization = 'Bearer ' + $credential.password;
    Accept = 'application/vnd.github+json'; 'User-Agent' = 'HD2-Drone-Release';
    'X-GitHub-Api-Version' = '2022-11-28' }
$api = "https://api.github.com/repos/$Repository"
$notes = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'RELEASE-0.2.20.md') -Raw -Encoding utf8
try {
    $remote = Invoke-RestMethod "$api/commits/$Commit" -Headers $headers
    if ($remote.sha -ne $Commit) { throw 'Source commit is not available on GitHub.' }
    $releases = Invoke-RestMethod "$api/releases?per_page=100" -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit;
            name = 'Drone Remote Control 0.2.20-test (Backpacks and Seekers)';
            body = $notes; draft = $true; prerelease = $true } | ConvertTo-Json
        $release = Invoke-RestMethod -Method Post "$api/releases" -Headers $headers `
            -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body))
    } elseif ($release.target_commitish -ne $Commit) {
        throw 'Existing release has another source commit; not replacing it.'
    }
    foreach ($expected in $assets) {
        $existing = $release.assets | Where-Object name -eq $expected.name | Select-Object -First 1
        if ($existing) {
            if ($existing.digest -ne "sha256:$($expected.sha256)" -or $existing.size -ne $expected.size) {
                throw 'Existing release asset differs; not replacing it.'
            }
        } else {
            $uri = $release.upload_url.Split('{')[0] + '?name=' + [Uri]::EscapeDataString($expected.name)
            $type = if ($expected.name.EndsWith('.zip')) { 'application/zip' } else { 'text/plain' }
            $uploaded = Invoke-RestMethod -Method Post $uri -Headers $headers `
                -ContentType $type -InFile $expected.path
            if ($uploaded.state -ne 'uploaded' -or $uploaded.size -ne $expected.size -or
                $uploaded.digest -ne "sha256:$($expected.sha256)") {
                throw 'Asset verification failed; draft remains unpublished.'
            }
        }
    }
    if ($release.draft) {
        $body = @{ draft = $false; prerelease = $true; make_latest = 'false' } | ConvertTo-Json
        $release = Invoke-RestMethod -Method Patch "$api/releases/$($release.id)" -Headers $headers `
            -ContentType 'application/json' -Body $body
    }
    $verified = Invoke-RestMethod "$api/releases/tags/$Tag" -Headers $headers
    if ($verified.draft -or -not $verified.prerelease) { throw 'Prerelease verification failed.' }
    $tagCommit = Invoke-RestMethod "$api/commits/$Tag" -Headers $headers
    if ($tagCommit.sha -ne $Commit) { throw 'Published tag does not match source commit.' }
    foreach ($expected in $assets) {
        $asset = $verified.assets | Where-Object name -eq $expected.name | Select-Object -First 1
        if ($asset.state -ne 'uploaded' -or $asset.size -ne $expected.size -or
            $asset.digest -ne "sha256:$($expected.sha256)") { throw 'Published asset verification failed.' }
    }
    [ordered]@{ url = $verified.html_url; prerelease = $verified.prerelease;
        sourceCommit = $Commit; assets = @($verified.assets | Select-Object name,size,digest,browser_download_url) } |
        ConvertTo-Json -Depth 4
} finally {
    $headers.Clear(); $credential.Clear(); $lines = $null
}
