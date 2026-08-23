#Requires -Version 7.0
<#
.SYNOPSIS
    Installe gdUnit4 si nécessaire et exécute la suite de tests en headless.

.DESCRIPTION
    gdUnit4 n'est pas versionné : il est téléchargé à une version épinglée et
    déposé dans addons/. Le dépôt ne porte donc pas 4 Mo de code tiers, et la
    version utilisée reste reproductible.

    L'option --ignoreHeadlessMode est passée sciemment : gdUnit4 refuse le
    mode headless par défaut parce que les InputEvents n'y sont pas transmis.
    L'invariant 2 interdit à la simulation de lire l'entrée, donc aucun test
    de ce socle n'en dépend, et il n'y a rien à contourner.

    Code de sortie : celui de gdUnit4. 0 si tout passe.

.PARAMETER GodotBin
    Chemin de l'exécutable Godot. À défaut : $env:GODOT_BIN, puis le PATH.

.PARAMETER Suite
    Chemins res:// de suites précises. Par défaut, tout res://tests.

.PARAMETER Reinstall
    Réinstalle gdUnit4 même s'il est déjà présent.

.EXAMPLE
    ./tools/test.ps1
.EXAMPLE
    ./tools/test.ps1 -Suite res://tests/tick_convergence_test.gd
#>
[CmdletBinding()]
param(
    [string] $GodotBin,
    [string[]] $Suite = @('res://tests'),
    [switch] $Reinstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = Resolve-GodotBinary -Explicit $GodotBin
$null = Assert-GodotVersion -GodotBinary $godot
$null = Confirm-GdUnit4 -ProjectRoot $projectRoot -Force:$Reinstall

# L'import enregistre les classes globales de gdUnit4 : sans lui, les suites
# de tests ne se chargent pas.
Write-Host ''
Write-Host '== Import du projet =='
$null = & $godot --headless --path $projectRoot --editor --quit 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host 'TEST KO : import du projet en echec.' -ForegroundColor Red
    exit 1
}

$runnerArgs = @(
    '--headless'
    '--path', $projectRoot
    '-s'
    '-d'
    # Port 0 n'est jamais lie : la connexion est refusee et le debogueur
    # interactif ne s'ouvre pas sur une erreur de script. Recommande par
    # gdUnit4 lui-meme.
    '--remote-debug', 'tcp://127.0.0.1:0'
    'res://addons/gdUnit4/bin/GdUnitCmdTool.gd'
    '--ignoreHeadlessMode'
)
foreach ($path in $Suite) {
    $runnerArgs += @('-a', $path)
}

Write-Host ''
Write-Host '== Suite de tests =='
& $godot @runnerArgs
$testExitCode = $LASTEXITCODE

Write-Host ''
if ($testExitCode -eq 0) {
    Write-Host 'TEST OK' -ForegroundColor Green
}
else {
    Write-Host "TEST KO : gdUnit4 sort avec le code $testExitCode." -ForegroundColor Red
}
exit $testExitCode
