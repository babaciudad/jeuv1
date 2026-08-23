<#
    Fonctions partagées par verify.ps1, test.ps1 et netharness.ps1.
    Ce fichier est destiné à être sourcé, jamais lancé directement.
#>

Set-StrictMode -Version Latest

function Resolve-GodotBinary {
    <#
        Résout l'exécutable Godot, dans l'ordre : paramètre explicite,
        $env:GODOT_BIN, puis le PATH. Lève si rien n'est trouvé : un chemin
        deviné silencieusement ferait échouer la vérification pour une
        mauvaise raison.
    #>
    [CmdletBinding()]
    param(
        [string] $Explicit
    )

    foreach ($candidate in @($Explicit, $env:GODOT_BIN)) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            if (Test-Path -LiteralPath $candidate) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
            throw "Godot introuvable au chemin indique : $candidate"
        }
    }

    $names = @(
        'godot',
        'Godot_v4.5-stable_win64_console.exe',
        'Godot_v4.5-stable_win64.exe'
    )
    foreach ($name in $names) {
        $command = Get-Command -Name $name -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return $command.Source
        }
    }

    throw @'
Godot introuvable.
Ajoutez-le au PATH, definissez $env:GODOT_BIN, ou passez -GodotBin <chemin>.
'@
}

function Get-ProjectScripts {
    <#
        Tous les scripts GDScript du projet, addons exclus : le code tiers
        n'a pas à respecter nos règles de typage et project.godot l'exclut
        déjà des avertissements.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ProjectRoot
    )

    $directories = @('src', 'tests', 'tools') |
        ForEach-Object { Join-Path $ProjectRoot $_ } |
        Where-Object { Test-Path -LiteralPath $_ }

    if ($directories.Count -eq 0) {
        return @()
    }

    return @(Get-ChildItem -Path $directories -Filter '*.gd' -Recurse -File | Sort-Object FullName)
}

function ConvertTo-ResPath {
    <# Chemin absolu -> chemin res:// attendu par le moteur. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ProjectRoot,
        [Parameter(Mandatory)] [string] $FullPath
    )

    $relative = [System.IO.Path]::GetRelativePath($ProjectRoot, $FullPath)
    return 'res://' + ($relative -replace '\\', '/')
}

function Assert-GodotVersion {
    <#
        Avertit si la version ne correspond pas à celle sur laquelle le projet
        est réglé. Avertit seulement : imposer une version exacte empêcherait
        de tester une montée de version.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $GodotBinary,
        [string] $Expected = '4.5'
    )

    $version = (& $GodotBinary --version 2>&1 | Select-Object -Last 1).ToString().Trim()
    if (-not $version.StartsWith($Expected)) {
        Write-Warning "Godot $version detecte, projet regle pour $Expected."
    }
    return $version
}

# Version épinglée de gdUnit4. La série v6.2.x est la première compatible
# Godot 4.5. Partagée par verify.ps1 et test.ps1 : les deux en dépendent, car
# les suites de tests héritent de GdUnitTestSuite et ne compilent pas sans.
$GdUnit4PinnedVersion = 'v6.2.1'

function Install-GdUnit4 {
    <#
        Installe l'addon depuis le dépôt amont, à un tag épinglé.
        Clone plutôt que téléchargement d'archive : l'endpoint d'archive de
        GitHub est souvent filtré par les proxys d'entreprise, alors que git
        sur HTTPS passe partout — et git est déjà un prérequis du projet.
        Clone superficiel d'un seul tag : quelques secondes, pas d'historique.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [string] $Version
    )

    if ($null -eq (Get-Command -Name 'git' -ErrorAction SilentlyContinue)) {
        throw "git est introuvable : impossible d'installer gdUnit4."
    }

    $workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("gdunit4-" + [System.Guid]::NewGuid().ToString('N'))

    Write-Host "Installation de gdUnit4 $Version..."
    try {
        & git -c advice.detachedHead=false clone --quiet --depth 1 --branch $Version 'https://github.com/MikeSchulze/gdUnit4.git' $workDir
        if ($LASTEXITCODE -ne 0) {
            throw "git clone de gdUnit4 $Version en echec (code $LASTEXITCODE)."
        }

        $extracted = Join-Path $workDir 'addons/gdUnit4'
        if (-not (Test-Path -LiteralPath $extracted)) {
            throw "Depot gdUnit4 inattendu : addons/gdUnit4 introuvable."
        }

        if (Test-Path -LiteralPath $Destination) {
            Remove-Item -LiteralPath $Destination -Recurse -Force
        }
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force
        Copy-Item -LiteralPath $extracted -Destination $Destination -Recurse -Force
        Write-Host "gdUnit4 $Version installe dans $Destination"
    }
    finally {
        if (Test-Path -LiteralPath $workDir) {
            # .git est en lecture seule sous Windows : on force.
            Get-ChildItem -LiteralPath $workDir -Recurse -Force |
                ForEach-Object { $_.Attributes = 'Normal' }
            Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Confirm-GdUnit4 {
    <#
        Garantit la présence de gdUnit4, sans rien faire s'il est déjà là.
        Appelé par verify.ps1 autant que par test.ps1 : les suites de tests
        font partie du projet et doivent être typées comme le reste, donc
        verify.ps1 a besoin de la classe de base pour les compiler.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ProjectRoot,
        [switch] $Force
    )

    $addonPath = Join-Path $ProjectRoot 'addons/gdUnit4'
    if ($Force -or -not (Test-Path -LiteralPath (Join-Path $addonPath 'plugin.cfg'))) {
        Install-GdUnit4 -Destination $addonPath -Version $GdUnit4PinnedVersion
    }
    return $addonPath
}
