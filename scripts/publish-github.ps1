# Publish committed documentation and apply the repository's public metadata.
param([string]$ProxyUrl, [switch]$UpdateInstalledSkill)

$ErrorActionPreference = 'Stop'
Write-Host '[1/6] Checking local repository and Git...'
$repoPath = Split-Path -Parent $PSScriptRoot
$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if ($gitCommand) {
    $gitExe = $gitCommand.Source
} else {
    $gitExe = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe'
}
if (-not (Test-Path -LiteralPath $gitExe)) { throw 'Git was not found.' }
Write-Host "Git: $gitExe"

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
if ($metadata.name -notmatch '^[A-Za-z0-9_-]+$') { throw 'Repository name is missing or invalid.' }
if ($UpdateInstalledSkill) {
    & (Join-Path $PSScriptRoot 'sync-installed-skill.ps1')
}

$networkOptions = @('-c', 'http.sslBackend=openssl', '-c', 'http.version=HTTP/1.1', '-c', 'http.lowSpeedLimit=1', '-c', 'http.lowSpeedTime=30')
$apiOptions = @{TimeoutSec = 30}
if (-not $ProxyUrl) {
    $configuredProxy = & $gitExe -C $repoPath config --get-urlmatch http.proxy $remote 2>$null
    $hasGitProxy = $LASTEXITCODE -eq 0
    $hasEnvironmentProxy = $env:HTTPS_PROXY -or $env:ALL_PROXY -or $env:HTTP_PROXY
    if (-not $hasGitProxy -and -not $hasEnvironmentProxy) {
        try {
            $githubUri = [Uri]'https://github.com/'
            $systemProxy = [Net.WebRequest]::GetSystemWebProxy().GetProxy($githubUri)
            if ($systemProxy -and $systemProxy.AbsoluteUri -ne $githubUri.AbsoluteUri) {
                $ProxyUrl = $systemProxy.AbsoluteUri
                Write-Host 'Using the Windows system proxy for Git and GitHub API requests.'
            }
        } catch {
            Write-Host 'Could not inspect the Windows system proxy. Existing Git/environment settings will be used.'
        }
    }
}
if ($ProxyUrl) {
    $proxyUri = $null
    if (-not [Uri]::TryCreate($ProxyUrl, [UriKind]::Absolute, [ref]$proxyUri) -or $proxyUri.Scheme -notin @('http', 'https') -or $proxyUri.UserInfo) {
        throw 'ProxyUrl must be an HTTP(S) proxy address without embedded credentials.'
    }
    $networkOptions += @('-c', "http.proxy=$ProxyUrl")
    $apiOptions.Proxy = $ProxyUrl
    Write-Host ('Network route: proxy ' + $proxyUri.Authority)
} else {
    Write-Host 'Network route: existing Git/environment settings; no additional proxy applied.'
}

Write-Host "[2/6] Pushing main to $owner/$repository..."
Write-Host 'Waiting here means Git is connecting, transferring, or requesting sign-in.'
Write-Host 'Network transfers abort after 30 seconds below 1 byte/second. Complete any GitHub sign-in prompt.'
& $gitExe -C $repoPath @networkOptions push --progress origin main
if ($LASTEXITCODE -ne 0) {
    throw 'Push failed before metadata updates. For a connection reset/timeout, check the proxy app or rerun with -ProxyUrl using its actual HTTP proxy address.'
}

$credentialLines = $null
$token = $null
$headers = $null
try {
    Write-Host '[3/6] Reading GitHub authorization from the configured Git helper...'
    # The credential helper returns a secret only in memory; never log or save it.
    $credentialLines = "protocol=https`nhost=github.com`n`n" | & $gitExe -C $repoPath @networkOptions credential fill
    if ($LASTEXITCODE -ne 0) { throw 'Cannot obtain GitHub credentials from the configured Git helper.' }
    foreach ($line in $credentialLines) {
        if ($line.StartsWith('password=')) { $token = $line.Substring(9) }
    }
    if (-not $token) { throw 'The Git credential helper did not return a token.' }
    $headers = @{
        Authorization = "Bearer $token"
        Accept = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
        'User-Agent' = 'simple-reviewer-publisher'
    }
    $api = "https://api.github.com/repos/$owner/$repository"
    $previousTls = [Net.ServicePointManager]::SecurityProtocol
    try {
        [Net.ServicePointManager]::SecurityProtocol = $previousTls -bor [Net.SecurityProtocolType]::Tls12
        Write-Host '[4/6] Updating the repository name, bilingual About description and topics...'
        $currentTopics = Invoke-RestMethod -Uri "$api/topics" -Headers $headers @apiOptions
        $topics = @(@($currentTopics.names) + @($metadata.topics) | Sort-Object -Unique)
        if ($topics.Count -gt 20) { throw 'Adding these topics would exceed the 20-topic limit.' }
        $descriptionBody = [Text.Encoding]::UTF8.GetBytes((@{name = $metadata.name; description = $metadata.description} | ConvertTo-Json -Compress))
        $topicsBody = [Text.Encoding]::UTF8.GetBytes((@{names = $topics} | ConvertTo-Json -Compress))
        $renamed = Invoke-RestMethod -Method Patch -Uri $api -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $descriptionBody @apiOptions
        if ($renamed.name -cne $metadata.name -or $renamed.owner.login -ine $owner) { throw 'Repository rename readback differs from the request.' }
        $repository = $renamed.name
        $api = "https://api.github.com/repos/$owner/$repository"
        $newRemote = "https://github.com/$owner/$repository.git"
        & $gitExe -C $repoPath remote set-url origin $newRemote
        if ($LASTEXITCODE -ne 0) { throw 'Repository was renamed but the local origin could not be updated.' }
        # Explicit push URLs would otherwise keep publishing to the old name.
        $pushUrls = @(& $gitExe -C $repoPath config --get-all remote.origin.pushurl)
        if ($pushUrls.Count -gt 0) {
            & $gitExe -C $repoPath config --replace-all remote.origin.pushurl $newRemote
            if ($LASTEXITCODE -ne 0) { throw 'Cannot update the explicit origin push URL.' }
        }
        $null = Invoke-RestMethod -Method Put -Uri "$api/topics" -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $topicsBody @apiOptions
        Write-Host '[5/6] Reading back the description and topics...'
        $result = Invoke-RestMethod -Uri $api -Headers $headers @apiOptions
        $resultTopics = Invoke-RestMethod -Uri "$api/topics" -Headers $headers @apiOptions
        if ($result.name -cne $metadata.name -or $result.description -cne $metadata.description) { throw 'Repository name or description readback differs from the requested value.' }
        if (@($topics | Where-Object { $_ -notin $resultTopics.names }).Count) { throw 'Topics readback is incomplete.' }
        $localHead = & $gitExe -C $repoPath rev-parse HEAD
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read local HEAD.' }
        Write-Host '[6/6] Comparing the local commit with GitHub main...'
        $remoteHead = & $gitExe -C $repoPath @networkOptions ls-remote origin refs/heads/main
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
