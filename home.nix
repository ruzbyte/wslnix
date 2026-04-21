{ pkgs, userConfig, ... }:
{
  home.username = userConfig.username;
  home.homeDirectory = "/home/${userConfig.username}";
  home.stateVersion = "25.11";
  
  imports = [
    ./zsh.nix
  ];

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
     neovim
  ];

  programs.git = {
    enable = true;
    userName = userConfig.username;       
    userEmail = userConfig.email;        
    extraConfig.init.defaultBranch = "main";
  };
}
