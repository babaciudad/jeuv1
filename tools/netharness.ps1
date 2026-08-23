#Requires -Version 7.0
<#
.SYNOPSIS
    Lance N instances locales du jeu avec latence et perte simulées.

.DESCRIPTION
    L'instance 1 est l'hôte (peer id 1, décision 4), les suivantes sont des
    clients qui se connectent à 127.0.0.1.

    La latence n'est pas injectée par un outil système : elle vit dans la
    couche transport (src/net/latency_pipe.gd). Conséquences voulues — pas de
    droits administrateur, fonctionne en headless, et le même mécanisme sert
    au test d'acceptation.

    -Latency est une latence d'ALLER SIMPLE, appliquée à la réception de
    chaque instance. -Latency 120 signifie donc 240 ms d'aller-retour.

.PARAMETER Instances
    Nombre d'instances, hôte compris. De 1 à 4 (SimConfig.MAX_PLAYERS).

.PARAMETER Latency
    Latence simulée en millisecondes, dans chaque sens.

.PARAMETER Loss
    Probabilité de perte par paquet, entre 0 et 1.

.PARAMETER Seconds
    Arrête tout après ce délai. 0 laisse tourner jusqu'à -Stop.

.PARAMETER Headless
    Lance sans fenêtre. Sert à vérifier le banc lui-même ; l'état d'horloge
    reste lisible dans logs/.

.PARAMETER Stop
    Arrête les instances lancées précédemment et sort.

.EXAMPLE
    ./tools/netharness.ps1 -Instances 2 -Latency 120
.EXAMPLE
    ./tools/netharness.ps1 -Instances 4 -Latency 80 -Loss 0.02
.EXAMPLE
    ./tools/netharness.ps1 -Stop
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 4)] [int] $Instances = 2,
    [ValidateRange(0, 10000)] [int] $Latency = 0,
    [ValidateRange(0.0, 1.0)] [double] $Loss = 0.0,
    [ValidateRange(1024, 65535)] [int] $Port = 45123,
    [int] $Seed = 0,
    [ValidateRange(0, 3600)] [int] $LogTicks = 60,
    [ValidateRange(0, 86400)] [int] $Seconds = 0,
    [switch] $Headless,
    [switch] $Stop,
    [string] $GodotBin
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

$projectRoot = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $projectRoot 'logs'
$pidFile = Join-Path $logDir 'netharness.pids'

function Stop-Harness {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $PidFile)

    if (-not (Test-Path -LiteralPath $PidFile)) {
        Write-Host 'Aucune instance enregistree.'
        return
    }
    $stopped = 0
    foreach ($line in Get-Content -LiteralPath $PidFile) {
        $processId = 0
        if (-not [int]::TryParse($line.Trim(), [ref] $processId)) {
            continue
        }
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if ($null -ne $process) {
            Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
            $stopped++
        }
    }
    Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
    Write-Host "$stopped instance(s) arretee(s)."
}

if ($Stop) {
    Stop-Harness -PidFile $pidFile
    exit 0
}

$godot = Resolve-GodotBinary -Explicit $GodotBin
$null = New-Item -ItemType Directory -Path $logDir -Force

# Une session precedente laissee en fond monopoliserait le port.
if (Test-Path -LiteralPath $pidFile) {
    Stop-Harness -PidFile $pidFile
}

Write-Host "Godot     : $godot"
Write-Host "Instances : $Instances (1 hote, $($Instances - 1) client(s))"
Write-Host "Reseau    : port $Port, latence $Latency ms par sens, perte $Loss"
Write-Host ''

$launched = [System.Collections.Generic.List[object]]::new()

for ($index = 1; $index -le $Instances; $index++) {
    $isHost = ($index -eq 1)
    $label = if ($isHost) { 'hote' } else { "client-$index" }

    $engineArgs = @()
    if ($Headless) {
        $engineArgs += '--headless'
    }
    else {
        # Tuilage simple : deux colonnes, pour que les fenetres ne se
        # recouvrent pas et que les ticks restent lisibles cote a cote.
        $column = ($index - 1) % 2
        $row = [math]::Floor(($index - 1) / 2)
        $engineArgs += @(
            '--resolution', '640x360'
            '--position', "$(40 + $column * 660),$(40 + $row * 420)"
        )
    }
    $engineArgs += @('--path', $projectRoot, '--')

    $userArgs = @('--port', "$Port", '--latency', "$Latency", '--loss', "$Loss",
                  '--seed', "$Seed", '--label', $label, '--log-ticks', "$LogTicks")
    if ($isHost) {
        $userArgs = @('--host') + $userArgs
    }
    else {
        $userArgs = @('--connect', '127.0.0.1') + $userArgs
    }

    $outLog = Join-Path $logDir "$label.log"
    $errLog = Join-Path $logDir "$label.err.log"

    $process = Start-Process -FilePath $godot `
        -ArgumentList ($engineArgs + $userArgs) `
        -RedirectStandardOutput $outLog `
        -RedirectStandardError $errLog `
        -PassThru

    $launched.Add([pscustomobject]@{ Label = $label; ProcessId = $process.Id; Log = $outLog })
    Write-Host ("  {0,-10} pid {1,-8} {2}" -f $label, $process.Id, $outLog)

    # L'hote doit avoir ouvert son socket avant qu'un client tente de s'y
    # connecter, sinon le client echoue au lieu d'attendre.
    if ($isHost -and $Instances -gt 1) {
        Start-Sleep -Milliseconds 1500
    }
}

$launched.ProcessId | Set-Content -LiteralPath $pidFile

Write-Host ''
if ($Seconds -gt 0) {
    Write-Host "Execution pendant $Seconds s..."
    Start-Sleep -Seconds $Seconds
    Stop-Harness -PidFile $pidFile
}
else {
    Write-Host 'Instances lancees. Pour les arreter : ./tools/netharness.ps1 -Stop'
}
exit 0
