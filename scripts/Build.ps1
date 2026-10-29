param([switch]$Test, [switch]$Package)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { $compiler = Join-Path $env:SystemRoot 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path -LiteralPath $compiler)) { throw '.NET Framework compiler was not found. Install .NET Framework 4.8 or use the binary release.' }
$bin = Join-Path $root 'bin'
New-Item -ItemType Directory -Path $bin -Force | Out-Null
$sources = @(Get-ChildItem -LiteralPath (Join-Path $root 'src') -Filter '*.cs' | ForEach-Object { $_.FullName })
$exe = Join-Path $bin 'WifiClashGuard.exe'
& $compiler /nologo /codepage:65001 /target:winexe /platform:anycpu /optimize+ /debug- /reference:System.Web.Extensions.dll "/out:$exe" $sources
if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
if ($Test) {
    $testExe = Join-Path $bin 'GuardTests.exe'
    & $compiler /nologo /codepage:65001 /target:exe /main:WifiClashGuard.GuardTests /platform:anycpu /optimize+ /debug- /reference:System.Web.Extensions.dll "/out:$testExe" $sources (Join-Path $root 'tests\GuardTests.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Test build failed.' }
    & $testExe
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
}
if ($Package) {
    $dist = Join-Path $root 'dist'
    New-Item -ItemType Directory -Path $dist -Force | Out-Null
    $stage = Join-Path $dist ('package-' + [Guid]::NewGuid().ToString('N'))
    $commands = @('Install.cmd','Enable.cmd','Disable.cmd','Status.cmd','Diagnose.cmd','Uninstall.cmd')
    $common = @('README.md','LICENSE','config.example.json') + $commands
    $releaseFiles = $common + @('bin\WifiClashGuard.exe','scripts\Common.ps1','scripts\Install.ps1','scripts\Manage.ps1')
    $sourceFiles = $common + @('.gitignore','.gitattributes','scripts\Common.ps1','scripts\Install.ps1','scripts\Manage.ps1','scripts\Build.ps1','src\Core.cs','src\NativeWifi.cs','src\Program.cs','tests\GuardTests.cs','tests\Test-TaskXml.ps1')
    try {
        foreach ($kind in @('windows','source')) {
            $targetRoot = Join-Path $stage $kind
            $files = if ($kind -eq 'windows') { $releaseFiles } else { $sourceFiles }
            foreach ($relative in $files) {
                $target = Join-Path $targetRoot $relative
                New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
                Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $target
            }
            if ($kind -eq 'windows') { Copy-Item -LiteralPath (Join-Path $root 'config.example.json') -Destination (Join-Path $targetRoot 'config.json') }
        }
        $zip = Join-Path $dist 'WifiClashGuard-v1.0.0-win.zip'
        $sourceZip = Join-Path $dist 'WifiClashGuard-v1.0.0-source.zip'
        Compress-Archive -Path (Join-Path $stage 'windows\*') -DestinationPath $zip -Force
        Compress-Archive -Path (Join-Path $stage 'source\*') -DestinationPath $sourceZip -Force
        $checksums = @($zip,$sourceZip) | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($_) }
        Set-Content -LiteralPath (Join-Path $dist 'SHA256SUMS.txt') -Value $checksums -Encoding ASCII
    } finally {
        $resolvedStage = [IO.Path]::GetFullPath($stage)
        $resolvedDist = [IO.Path]::GetFullPath($dist).TrimEnd('\') + '\'
        if (-not $resolvedStage.StartsWith($resolvedDist, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing cleanup outside dist.' }
        if (Test-Path -LiteralPath $resolvedStage) { Remove-Item -LiteralPath $resolvedStage -Recurse -Force }
    }
    Write-Host 'Windows/source ZIPs and checksums generated in dist/.'
}
Write-Host 'Build OK.'

