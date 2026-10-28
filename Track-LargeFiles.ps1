[CmdletBinding()]
param(
    [ValidateRange(0.000001, 1048576)]
    [double]$MinimumSizeMiB = 50
)

$ErrorActionPreference = 'Stop'
$gitExe = (Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$minimumBytes = [long][Math]::Ceiling($MinimumSizeMiB * 1MB)

function Invoke-CheckedGit {
    param([string[]]$GitArguments)
    & $gitExe @GitArguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArguments[0]) failed (exit $LASTEXITCODE)."
    }
}

function Get-RepositoryPaths {
    # Read UTF-8 and NUL separators explicitly, including in Windows PowerShell 5.1.
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $gitExe
    $startInfo.Arguments = 'ls-files -z --cached --others --exclude-standard'
    $startInfo.WorkingDirectory = $PSScriptRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $startInfo.StandardErrorEncoding = New-Object System.Text.UTF8Encoding($false)
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) {
            throw "git ls-files failed (exit $($process.ExitCode)): $stderr"
        }
        $stdout.Split([char]0, [System.StringSplitOptions]::RemoveEmptyEntries)
    }
    finally {
        $process.Dispose()
    }
}

Push-Location -LiteralPath $PSScriptRoot
try {
    Invoke-CheckedGit -GitArguments @('rev-parse', '--is-inside-work-tree') | Out-Null
    Invoke-CheckedGit -GitArguments @('lfs', 'install', '--local')

    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $added = 0
    $alreadyTracked = 0
    foreach ($relativePath in Get-RepositoryPaths) {
        if (-not $seen.Add($relativePath)) { continue }
        $fullPath = Join-Path $PSScriptRoot $relativePath
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { continue }
        $file = Get-Item -LiteralPath $fullPath -Force
        if ($file.Length -lt $minimumBytes) { continue }

        $attribute = @(Invoke-CheckedGit -GitArguments @('check-attr', 'filter', '--', $relativePath))
        if ($attribute.Count -gt 0 -and $attribute[-1] -match ': filter: lfs$') {
            $alreadyTracked++
            continue
        }
        Invoke-CheckedGit -GitArguments @('lfs', 'track', '--filename', '--', $relativePath)
        $added++
    }
    Write-Host "LFS scan complete (minimum $MinimumSizeMiB MiB): $added new rule(s), $alreadyTracked already tracked."
    Write-Host 'Review .gitattributes, then run git add, git commit and git push as usual.'
}
finally {
    Pop-Location
}
