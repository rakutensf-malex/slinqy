Get-ChildItem

.\psake.4.4.2\tools\psake .\Source\Scripts\CI.Tasks.ps1 $args -parameters @{BasePath=$PSScriptRoot} -nologo -framework 4.6

if ($LASTEXITCODE -ne 0) {
    throw "PSake failed with exit code $LASTEXITCODE.  See previous errors for details."
}