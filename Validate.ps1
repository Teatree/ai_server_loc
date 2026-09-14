$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$pythonPath = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
& $pythonPath -m unittest discover -s tests -v
if ($LASTEXITCODE -ne 0) { throw 'Gateway tests failed' }
node --test tests/frontend.test.cjs
if ($LASTEXITCODE -ne 0) { throw 'Frontend security checks failed' }
Write-Host 'Mock-only security and relay tests passed. No live AI operations were tested.'
