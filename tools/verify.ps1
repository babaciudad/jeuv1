#Requires -Version 7.0
<#
.SYNOPSIS
    Vérifie que le projet compile et respecte le typage statique strict.

.DESCRIPTION
    Deux étapes :
      1. un passage d'import, qui enregistre les classes globales et sans
         lequel tout script référençant une autre classe échouerait ;
      2. une analyse fichier par fichier via --check-only.

    gdUnit4 est installé au besoin : les suites de tests en héritent et ne
    compileraient pas sans lui sur un dépôt fraîchement cloné.

    Le « lint » n'est pas un outil tiers : c'est le jeu d'avertissements de
    GDScript promu en erreurs dans project.godot (untyped_declaration,
    inferred_declaration, unsafe_*). Un script non typé ne compile donc pas,
    et ressort ici.

    Code de sortie binaire : 0 si tout passe, 1 sinon. Rien d'autre.

.PARAMETER GodotBin
    Chemin de l'exécutable Godot. À défaut : $env:GODOT_BIN, puis le PATH.

.EXAMPLE
    ./tools/verify.ps1
#>
[CmdletBinding()]
param(
    [string] $GodotBin
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = Resolve-GodotBinary -Explicit $GodotBin

Write-Host "Godot   : $godot"
Write-Host "Projet  : $projectRoot"
Write-Host ''

# Les suites de tests heritent de GdUnitTestSuite : sans l'addon, elles ne
# compilent pas et la verification echouerait sur un clone neuf.
$null = Confirm-GdUnit4 -ProjectRoot $projectRoot

Write-Host '== Import du projet =='
$importOutput = & $godot --headless --path $projectRoot --editor --quit 2>&1
if ($LASTEXITCODE -ne 0) {
    $importOutput | Write-Host
    Write-Host 'VERIFY KO : import du projet en echec.' -ForegroundColor Red
    exit 1
}

$scriptFiles = Get-ProjectScripts -ProjectRoot $projectRoot
if ($scriptFiles.Count -eq 0) {
    Write-Host 'VERIFY KO : aucun script a verifier, ce qui ne devrait pas arriver.' -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host "== Analyse de $($scriptFiles.Count) script(s) =="
$failed = [System.Collections.Generic.List[string]]::new()

foreach ($file in $scriptFiles) {
    $resPath = ConvertTo-ResPath -ProjectRoot $projectRoot -FullPath $file.FullName
    $output = & $godot --headless --path $projectRoot --check-only --script $resPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        $failed.Add($resPath)
        Write-Host "  ECHEC $resPath" -ForegroundColor Red
        $output |
            Where-Object { $_ -match 'Parse Error|SCRIPT ERROR|Failed to load' } |
            ForEach-Object { Write-Host "         $_" -ForegroundColor DarkRed }
    }
    else {
        Write-Host "  ok    $resPath"
    }
}

Write-Host ''
if ($failed.Count -gt 0) {
    Write-Host "VERIFY KO : $($failed.Count) script(s) en echec sur $($scriptFiles.Count)." -ForegroundColor Red
    exit 1
}

Write-Host "VERIFY OK : $($scriptFiles.Count) script(s) compiles et types." -ForegroundColor Green
exit 0
