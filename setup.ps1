# install-nixos-wsl.ps1
# End-to-end NixOS-WSL setup with custom user

# ============================================================================
# CONFIGURATION
# ============================================================================

$DistroName = "NixOS"
$InstallPath = "$env:USERPROFILE\WSL\NixOS"
$DownloadPath = "$env:TEMP\nixos.wsl"
$RepoUrl = "https://github.com/DEINUSER/wslnix.git"   # ← anpassen

# ============================================================================
# PROMPTS
# ============================================================================

function Get-UserInput {
    Write-Host "=== NixOS-WSL Setup ===" -ForegroundColor Cyan
    Write-Host ""

    $username = ""
    while ([string]::IsNullOrWhiteSpace($username)) {
        $username = Read-Host "Username"
    }

    $email = ""
    while ([string]::IsNullOrWhiteSpace($email)) {
        $email = Read-Host "Git email"
    }

    $hostname = Read-Host "Hostname (default: nixos-wsl)"
    if ([string]::IsNullOrWhiteSpace($hostname)) {
        $hostname = "nixos-wsl"
    }

    return @{
        Username = $username
        Email    = $email
        Hostname = $hostname
    }
}

# ============================================================================
# WSL INSTALL
# ============================================================================

function Ensure-WSL {
    $wslStatus = wsl --status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Installing WSL..." -ForegroundColor Cyan
        wsl --install --no-distribution
        Write-Host "WSL installed. Reboot and re-run this script." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "✓ WSL is available" -ForegroundColor Green
}

# ============================================================================
# DOWNLOAD NIXOS-WSL
# ============================================================================

function Get-LatestNixOSWSL {
    Write-Host "Fetching latest NixOS-WSL release..." -ForegroundColor Cyan

    $release = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/nix-community/NixOS-WSL/releases/latest" `
        -Headers @{
            "Accept"     = "application/vnd.github+json"
            "User-Agent" = "NixOS-WSL-Installer"
        }

    $asset = $release.assets | Where-Object { $_.name -like "*.wsl" } | Select-Object -First 1
    if (-not $asset) {
        throw "No .wsl asset in latest release"
    }

    Write-Host "Downloading $($asset.name)..." -ForegroundColor Cyan
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $DownloadPath -UseBasicParsing
    $ProgressPreference = 'Continue'

    Write-Host "✓ Download complete" -ForegroundColor Green
}

# ============================================================================
# IMPORT DISTRO
# ============================================================================

function Import-NixOS {
    # Check ob NixOS schon existiert
    $existing = wsl --list --quiet 2>$null | Where-Object { $_.Trim() -eq $DistroName }
    if ($existing) {
        Write-Warning "Distribution '$DistroName' already exists."
        $answer = Read-Host "Unregister and reinstall? (y/N)"
        if ($answer -ne "y") {
            Write-Host "Aborted." -ForegroundColor Red
            exit 1
        }
        wsl --unregister $DistroName
    }

    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }

    Write-Host "Importing NixOS..." -ForegroundColor Cyan
    wsl --install --from-file $DownloadPath --name $DistroName

    if ($LASTEXITCODE -ne 0) {
        throw "WSL import failed"
    }
    Write-Host "✓ NixOS imported" -ForegroundColor Green
}

# ============================================================================
# BOOTSTRAP INSIDE WSL
# ============================================================================

function Bootstrap-NixOS {
    param($config)

    Write-Host "Bootstrapping NixOS inside WSL..." -ForegroundColor Cyan

    # Bootstrap-Script direkt in WSL ausführen
    # Hier wird der Default-User (nixos) zu deinem Username umbenannt,
    # behält aber UID 1000 → kein 1001-Konflikt
    $bootstrap = @"
set -e

# 1. Config-Verzeichnis anlegen
mkdir -p `$HOME/.config/nixos-wsl

# 2. User-Config schreiben
cat > `$HOME/.config/nixos-wsl/user.nix <<EOF
{
  username = "$($config.Username)";
  email = "$($config.Email)";
  hostname = "$($config.Hostname)";
}
EOF

# 3. Repo klonen
if [ ! -d `$HOME/wslnix ]; then
  nix-shell -p git --run "git clone $RepoUrl `$HOME/wslnix"
fi

echo "✓ Bootstrap complete. Config at `$HOME/.config/nixos-wsl/user.nix"
"@

    $bootstrap | wsl -d $DistroName -u nixos bash

    if ($LASTEXITCODE -ne 0) {
        throw "Bootstrap failed inside WSL"
    }
}

# ============================================================================
# FIRST REBUILD
# ============================================================================

function First-Rebuild {
    param($config)

    Write-Host "Running first nixos-rebuild (this takes a few minutes)..." -ForegroundColor Cyan

    $rebuild = @"
set -e
cd `$HOME/wslnix
sudo nixos-rebuild switch --flake .#wsl --impure
"@

    $rebuild | wsl -d $DistroName -u nixos bash

    if ($LASTEXITCODE -ne 0) {
        throw "First rebuild failed"
    }
    Write-Host "✓ First rebuild done" -ForegroundColor Green
}

# ============================================================================
# FIX DEFAULT USER (Windows Registry)
# ============================================================================

function Set-DefaultUser {
    param($config)

    Write-Host "Setting default user in Windows Registry..." -ForegroundColor Cyan

    # UID im frisch gebuildeten System rausfinden
    $uid = (wsl -d $DistroName -u root -- id -u $config.Username).Trim()

    if (-not ($uid -match '^\d+$')) {
        throw "Could not determine UID for $($config.Username)"
    }

    Write-Host "  Username: $($config.Username)" -ForegroundColor DarkGray
    Write-Host "  UID:      $uid" -ForegroundColor DarkGray

    # Registry-Key finden und DefaultUid setzen
    $distro = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\*' |
        Where-Object DistributionName -eq $DistroName

    if (-not $distro) {
        throw "Could not find WSL registry key for $DistroName"
    }

    Set-ItemProperty -Path $distro.PSPath -Name DefaultUid -Value ([int]$uid)
    Write-Host "✓ Default UID set to $uid" -ForegroundColor Green
}

# ============================================================================
# MAIN
# ============================================================================

try {
    $config = Get-UserInput

    Ensure-WSL
    Get-LatestNixOSWSL
    Import-NixOS
    Bootstrap-NixOS -config $config
    First-Rebuild -config $config
    Set-DefaultUser -config $config

    # WSL durchstarten damit der neue Default-User greift
    Write-Host ""
    Write-Host "Shutting down WSL..." -ForegroundColor Cyan
    wsl --shutdown
    Start-Sleep -Seconds 2

    Write-Host ""
    Write-Host "=== Setup complete ===" -ForegroundColor Green
    Write-Host "Start NixOS with:" -ForegroundColor Cyan
    Write-Host "  wsl -d $DistroName" -ForegroundColor White
    Write-Host ""
    Write-Host "You'll be logged in as '$($config.Username)'." -ForegroundColor Cyan
    Write-Host ""

    # Cleanup
    Remove-Item $DownloadPath -ErrorAction SilentlyContinue

} catch {
    Write-Host ""
    Write-Host "✗ Setup failed: $_" -ForegroundColor Red
    exit 1
}