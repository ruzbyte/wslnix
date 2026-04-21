# setup.ps1 - NixOS-WSL end-to-end setup

# ============================================================================
# CONFIGURATION
# ============================================================================

$DistroName = "NixOS"
$InstallPath = "$env:USERPROFILE\WSL\NixOS"
$DownloadPath = "$env:TEMP\nixos.wsl"
$RepoUrl = "https://github.com/ruzbyte/wslnix.git"

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
# WSL
# ============================================================================

function Ensure-WSL {
    wsl --status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Installing WSL..." -ForegroundColor Cyan
        wsl --install --no-distribution
        Write-Host "WSL installed. Reboot and re-run this script." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "WSL is available" -ForegroundColor Green
}

# ============================================================================
# DOWNLOAD
# ============================================================================

function Get-LatestNixOSWSL {
    Write-Host "Fetching latest NixOS-WSL release..." -ForegroundColor Cyan

    if (Test-Path $DownloadPath) {
        Write-Host "Already downloaded: $DownloadPath" -ForegroundColor Green
        return
    }
    
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

    Write-Host "Download complete" -ForegroundColor Green
}

# ============================================================================
# IMPORT
# ============================================================================

function Import-NixOS {
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
    Write-Host "NixOS imported" -ForegroundColor Green
}

# ============================================================================
# BOOTSTRAP
# ============================================================================

function Bootstrap-NixOS {
    param($config)

    Write-Host "Bootstrapping NixOS inside WSL..." -ForegroundColor Cyan

    $envSetup = "export NIXOS_USERNAME='$($config.Username)'`n" +
                "export NIXOS_EMAIL='$($config.Email)'`n" +
                "export NIXOS_HOSTNAME='$($config.Hostname)'`n" +
                "export NIXOS_REPO_URL='$RepoUrl'`n"

    $bootstrap = @'
set -e

mkdir -p "$HOME/.config/nixos-wsl"

cat > "$HOME/.config/nixos-wsl/user.nix" <<EOF
{
  username = "$NIXOS_USERNAME";
  email = "$NIXOS_EMAIL";
  hostname = "$NIXOS_HOSTNAME";
}
EOF

if [ ! -d "$HOME/wslnix" ]; then
  nix-shell -p git --run "git clone $NIXOS_REPO_URL $HOME/wslnix"
fi

echo "Bootstrap complete"
'@

    $fullScript = $envSetup + $bootstrap
    $fullScript = $fullScript -replace "`r`n", "`n"        # CRLF -> LF fix
    $fullScript | wsl -d $DistroName -u nixos bash

    if ($LASTEXITCODE -ne 0) {
        throw "Bootstrap failed inside WSL"
    }
}

function First-Rebuild {
    Write-Host "Running first nixos-rebuild (this takes a few minutes)..." -ForegroundColor Cyan

    $rebuild = @'
set -e
cd "$HOME/wslnix"
nix-shell -p git --run "sudo --preserve-env=PATH nixos-rebuild switch --flake .#wsl --option pure-eval 0"
'@

    $rebuild = $rebuild -replace "`r`n", "`n"               # CRLF -> LF fix
    $rebuild | wsl -d $DistroName -u nixos bash

    if ($LASTEXITCODE -ne 0) {
        throw "First rebuild failed"
    }
    Write-Host "First rebuild done" -ForegroundColor Green
}

# ============================================================================
# FIX DEFAULT USER
# ============================================================================

function Set-DefaultUser {
    param($config)

    Write-Host "Setting default user in Windows Registry..." -ForegroundColor Cyan

    $uid = (wsl -d $DistroName -u root -- id -u $config.Username).Trim()

    if (-not ($uid -match '^\d+$')) {
        throw "Could not determine UID for $($config.Username)"
    }

    Write-Host "  Username: $($config.Username)" -ForegroundColor DarkGray
    Write-Host "  UID:      $uid" -ForegroundColor DarkGray

    $lxssPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
    $distro = Get-ChildItem -Path $lxssPath |
        Get-ItemProperty |
        Where-Object { $_.DistributionName -eq $DistroName } |
        Select-Object -First 1

    if (-not $distro) {
        throw "Could not find WSL registry key for $DistroName"
    }

    Set-ItemProperty -Path $distro.PSPath -Name DefaultUid -Value ([int]$uid)
    Write-Host "Default UID set to $uid" -ForegroundColor Green
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
    First-Rebuild
    Set-DefaultUser -config $config

    Write-Host ""
    Write-Host "Shutting down WSL..." -ForegroundColor Cyan
    wsl --shutdown
    Start-Sleep -Seconds 2

    Write-Host ""
    Write-Host "=== Setup complete ===" -ForegroundColor Green
    Write-Host "Start NixOS with:" -ForegroundColor Cyan
    Write-Host "  wsl -d $DistroName" -ForegroundColor White
    Write-Host ""
    Write-Host "You will be logged in as '$($config.Username)'." -ForegroundColor Cyan
    Write-Host ""

    Remove-Item $DownloadPath -ErrorAction SilentlyContinue

} catch {
    Write-Host ""
    Write-Host "Setup failed: $_" -ForegroundColor Red
    exit 1
}