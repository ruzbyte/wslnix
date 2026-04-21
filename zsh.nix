{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion    = true;
    autosuggestion.enable  = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      # eza
      ls   = "eza --icons --group-directories-first";
      ll   = "eza -l --icons --group-directories-first";
      la   = "eza -a --icons";
      lla  = "eza -la --icons";
      tree = "eza --tree --icons";

      # Git
      gs   = "git status";
      ga   = "git add";
      gc   = "git commit";
      gp   = "git push";
      gl   = "git log";
      gd   = "git diff";
      gco  = "git checkout";
      gb   = "git branch";
      gcb  = "git checkout -b";
      gcm  = "git commit -m";
      gpl  = "git pull";
      gst  = "git stash";
      gsta = "git stash apply";
      gstd = "git stash drop";
      gss  = "git stash show -p";

      dc   = "docker compose";
      dcb  = "docker compose build";
      dcu  = "docker compose up";
      dcd  = "docker compose down";
      dl   = "docker logs -f";
      dps  = "docker ps";

      nrs  = "sudo nixos-rebuild switch --flake ~/nixconfig#wsl";
      nrt  = "sudo nixos-rebuild test   --flake ~/nixconfig#wsl";
      nrsu = "sudo nixos-rebuild switch --flake ~/nixconfig#wsl --upgrade";
      nfu  = "nix flake update ~/nixconfig";
      nsh  = "nix shell";
      ngc   = "sudo nix-collect-garbage -d --delete-older-than 7d";
      ngca  = "sudo nix-collect-garbage -d";

      vim  = "nvim";
      cat  = "bat";
      cd   = "z";
      cdi  = "zi";
      zsrc = "source ~/.zshrc";
    };

    initContent = ''
      setopt AUTO_CD
      setopt CORRECT
      HISTSIZE=10000
      SAVEHIST=10000
      HISTFILE=~/.zsh_history

      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-z1-2}={A-Z1-2}'

      bindkey "^[[1;5C" forward-word
      bindkey "^[[1;5D" backward-word

      fastfetch
    '';
  };

  programs.starship = {
    enable = true;
    settings = {
      "$schema" = "https://starship.rs/config-schema.json";

      format = "[░▒▓](#a3aed2)[$username$hostname  ](bg:#a3aed2 fg:#090c0c)[](bg:#769ff0 fg:#a3aed2)$directory[](fg:#769ff0 bg:#394260)$git_branch$git_status[](fg:#394260 bg:#212736)$nodejs$rust$golang$php[](fg:#212736 bg:#1d2230)$time[ ](fg:#1d2230)\n$character";

      username = {
        show_always = true;
        style_user = "fg:#a0a9cb bg:#1d2230";
        style_root = "fg:#a0a9cb bg:#1d2230";
        format = "[  $user ]($style)";
      };

      hostname = {
        ssh_only = false;
        style = "fg:#e3e5e5 bg:#1d2230";
        format = "[ 󰍹 $hostname ]($style)";
      };

      directory = {
        style = "fg:#e3e5e5 bg:#769ff0";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
        substitutions = {
          "Documents" = "󰈙 ";
          "Downloads" = " ";
          "Music" = " ";
          "Pictures" = " ";
        };
      };

      git_branch = {
        symbol = "";
        style = "bg:#394260";
        format = "[[ $symbol $branch ](fg:#769ff0 bg:#394260)]($style)";
      };

      git_status = {
        style = "bg:#394260";
        format = "[[($all_status$ahead_behind )](fg:#769ff0 bg:#394260)]($style)";
      };

      nodejs = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };

      rust = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };

      golang = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };

      php = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:#1d2230";
        format = "[[  $time ](fg:#a0a9cb bg:#1d2230)]($style)";
      };
    };
  };

  xdg.configFile = {

    "fastfetch/config.jsonc".text = ''
      {
        "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
        "display": {
          "separator": " : "
        },
        "modules": [
          {
            "type": "chassis",
            "key": "  󰇺 Chassis",
            "format": "{1}"
          },
          {
            "type": "os",
            "key": "  󰣇 OS",
            "format": "{2}",
            "keyColor": "red"
          },
          {
            "type": "kernel",
            "key": "   Kernel",
            "format": "{2}",
            "keyColor": "red"
          },
          {
            "type": "packages",
            "key": "  󰏗 Packages",
            "keyColor": "green"
          },
          {
            "type": "display",
            "key": "  󰍹 Display",
            "format": "{1}x{2} @ {3}Hz [{7}]",
            "keyColor": "green"
          },
          {
            "type": "terminal",
            "key": "   Terminal",
            "keyColor": "yellow"
          },
          {
            "type": "wm",
            "key": "  󱗃 WM",
            "format": "{2}",
            "keyColor": "yellow"
          },
          {
            "type": "custom",
            "format": "───────────────────────────────────────────────────"
          },
          "break",
          {
            "type": "title",
            "key": "  ",
            "format": "{6} {7} {8}"
          },
          {
            "type": "custom",
            "format": "───────────────────────────────────────────────────"
          },
          {
            "type": "cpu",
            "format": "{1}",
            "key": "   CPU",
            "keyColor": "blue"
          },
          {
            "type": "gpu",
            "format": "{1} {2}",
            "key": "  󰊴 GPU",
            "keyColor": "blue"
          },
          {
            "type": "gpu",
            "format": "{3}",
            "key": "   GPU Driver",
            "keyColor": "magenta"
          },
          {
            "type": "memory",
            "key": "  Memory ",
            "keyColor": "magenta"
          },
          {
            "type": "disk",
            "key": "  󱦟 OS Age ",
            "folders": "/",
            "keyColor": "red",
            "format": "{days} days"
          },
          {
            "type": "uptime",
            "key": "  󱫐 Uptime ",
            "keyColor": "red"
          },
          {
            "type": "custom",
            "format": "───────────────────────────────────────────────────"
          },
          {
            "type": "colors",
            "paddingLeft": 2,
            "symbol": "circle"
          },
          "break"
        ]
      }
    '';
  };

  home.packages = with pkgs; [
    bat
    eza
    fd
    ripgrep
    fzf
    jq
    htop
    btop
    lazygit
    zoxide
    fastfetch
  ];

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
