# Publish committed documentation and apply the repository's public metadata.
$ErrorActionPreference = 'Stop'
$repoPath = Split-Path -Parent $PSScriptRoot
$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if ($gitCommand) {
    $gitExe = $gitCommand.Source
} else {
    $gitExe = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe'
}
if (-not (Test-Path -LiteralPath $gitExe)) { throw 'Git was not found.' }

$remote = & $gitExe -C $repoPath remote get-url origin
if ($LASTEXITCODE -ne 0) { throw 'Cannot read origin.' }
if ($remote -notmatch '^https://github\.com/([A-Za-z0-9_-]+)/([A-Za-z0-9_.-]+?)(?:\.git)?/?$') {
    throw 'This publishing helper requires an HTTPS github.com origin.'
}
$owner = $Matches[1]
$repository = $Matches[2]
$branch = & $gitExe -C $repoPath branch --show-current
if ($LASTEXITCODE -ne 0 -or $branch -ne 'main') { throw 'Switch to main before publishing.' }
$dirty = & $gitExe -C $repoPath status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Commit local changes before publishing.' }
$metadataPath = Join-Path $repoPath 'assets\github-metadata.json'
$metadata = Get-Content -LiteralPath $metadataPath -Encoding UTF8 -Raw | ConvertFrom-Json
if (-not $metadata.description -or -not $metadata.topics) { throw 'Repository metadata is incomplete.' }

& $gitExe -C $repoPath -c http.sslBackend=openssl push origin main
if ($LASTEXITCODE -ne 0) { throw 'Push failed. Repository metadata was not changed.' }

$credentialLines = $null
$token = $null
$headers = $null
try {
    # The credential helper returns a secret only in memory; never log or save it.
    $credentialLines = "protocol=https`nhost=github.com`n`n" | & $gitExe -C $repoPath credential fill
    if ($LASTEXITCODE -ne 0) { throw 'Cannot obtain GitHub credentials from the configured Git helper.' }
    foreach ($line in $credentialLines) {
        if ($line.StartsWith('password=')) { $token = $line.Substring(9) }
    }
    if (-not $token) { throw 'The Git credential helper did not return a token.' }
    $headers = @{
        Authorization = "Bearer $token"
        Accept = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
        'User-Agent' = 'simple-checker-publisher'
    }
    $api = "https://api.github.com/repos/$owner/$repository"
    $previousTls = [Net.ServicePointManager]::SecurityProtocol
    try {
        [Net.ServicePointManager]::SecurityProtocol = $previousTls -bor [Net.SecurityProtocolType]::Tls12
        $currentTopics = Invoke-RestMethod -Uri "$api/topics" -Headers $headers
        $topics = @(@($currentTopics.names) + @($metadata.topics) | Sort-Object -Unique)
        if ($topics.Count -gt 20) { throw 'Adding these topics would exceed the 20-topic limit.' }
        $descriptionBody = [Text.Encoding]::UTF8.GetBytes((@{description = $metadata.description} | ConvertTo-Json -Compress))
        $topicsBody = [Text.Encoding]::UTF8.GetBytes((@{names = $topics} | ConvertTo-Json -Compress))
        $null = Invoke-RestMethod -Method Patch -Uri $api -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $descriptionBody
        $null = Invoke-RestMethod -Method Put -Uri "$api/topics" -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $topicsBody
        $result = Invoke-RestMethod -Uri $api -Headers $headers
        $resultTopics = Invoke-RestMethod -Uri "$api/topics" -Headers $headers
        if ($result.description -cne $metadata.description) { throw 'Description readback differs from the requested value.' }
        if (@($topics | Where-Object { $_ -notin $resultTopics.names }).Count) { throw 'Topics readback is incomplete.' }
        $localHead = & $gitExe -C $repoPath rev-parse HEAD
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read local HEAD.' }
        $remoteHead = & $gitExe -C $repoPath -c http.sslBackend=openssl ls-remote origin refs/heads/main
        if ($LASTEXITCODE -ne 0 -or -not $remoteHead -or ($remoteHead -split '\s+')[0] -ne $localHead) {
            throw 'Remote main does not match the local commit.'
        }
        Write-Host "Published and verified: https://github.com/$owner/$repository"
        Write-Host "Commit: $localHead"
        Write-Host ('Topics: ' + ($resultTopics.names -join ', '))
    } finally {
        [Net.ServicePointManager]::SecurityProtocol = $previousTls
    }
} finally {
    $credentialLines = $null
    $token = $null
    $headers = $null
}
