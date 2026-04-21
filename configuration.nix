# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{ userConfig, config, lib, pkgs, ... }:

{
  wsl.enable = true;
  wsl.defaultUser = userConfig.username;
  wsl.useWindowsDriver = true;
  programs.nix-ld.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";
  
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    vim
  ];

  programs.zsh.enable = true;
  
  users.users.${userConfig.username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    uid = 1001;
    shell = pkgs.zsh;
  };
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
