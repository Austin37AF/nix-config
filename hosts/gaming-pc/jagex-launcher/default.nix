# Home Manager module: `programs.jagex-launcher`, Jagex's official Windows launcher (OSRS,
# RuneLite, RS3) run through umu-launcher and Proton-GE in its own Wine prefix.
#
# First launch copies the launcher into the prefix; it updates itself from then on. Install
# RuneLite from inside the launcher (OSRS > game client).
#
# A user service inhibits KDE screen-off and locking while RuneLite runs (inhibitIdleWhileRunning).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.jagex-launcher;

  # Jagex's Windows installer fails under Wine ("Internet Explorer not supported"), so build its
  # install folder from Jagex's CDN instead. Pinned to a metafile; the launcher self-updates.
  launcherFiles = pkgs.stdenvNoCC.mkDerivation {
    name = "jagex-launcher-files";
    nativeBuildInputs = [
      pkgs.python3
      pkgs.cacert
    ];
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    dontUnpack = true;
    installPhase = "python3 ${./fetch-launcher.py} ${cfg.metafile.id} $out";
    outputHashMode = "recursive";
    outputHash = cfg.metafile.hash;
  };

  launcher = pkgs.writeShellApplication {
    name = "jagex-launcher";
    runtimeInputs = [
      pkgs.umu-launcher
      pkgs.curl
      pkgs.coreutils
    ];
    runtimeEnv = {
      LAUNCHER_FILES = launcherFiles;
      WINEPREFIX = cfg.prefix;
      GAMEID = "umu-default";
      PROTONPATH = "${pkgs.proton-ge-bin.steamcompattool}";
      # Windows Java (RuneLite) crashes at startup on Wine's AF_UNIX sockets; a socket dir that
      # doesn't exist makes it fall back to TCP loopback. Inherited by the games it launches.
      JAVA_TOOL_OPTIONS = "-Djdk.net.unixdomain.tmpdir=C:\\nonexistent-afunix";
    };
    text = builtins.readFile ./jagex-launcher.sh;
  };

  inhibitor = pkgs.writeShellApplication {
    name = "runelite-inhibit";
    runtimeInputs = [
      pkgs.procps
      pkgs.kdePackages.kde-cli-tools
      pkgs.coreutils
    ];
    text = ''
      while true; do
        if pgrep -x RuneLite.exe >/dev/null; then
          kde-inhibit --power --screenSaver sh -c 'while pgrep -x RuneLite.exe >/dev/null; do sleep 30; done'
        fi
        sleep 30
      done
    '';
  };

  desktopItem = pkgs.makeDesktopItem {
    name = "jagex-launcher";
    desktopName = "Jagex Launcher";
    comment = "Old School RuneScape, RuneLite and RuneScape";
    exec = lib.getExe launcher;
    categories = [ "Game" ];
  };
in
{
  options.programs.jagex-launcher = {
    enable = lib.mkEnableOption "the official Jagex Launcher via umu-launcher";
    prefix = lib.mkOption {
      description = "Wine prefix holding the Jagex Launcher and its games";
      type = lib.types.str;
      default = "${config.xdg.dataHome}/jagex-umu/prefix";
    };
    inhibitIdleWhileRunning = lib.mkOption {
      description = "Keep the screen awake and unlocked (KDE) while RuneLite is running";
      type = lib.types.bool;
      default = true;
    };
    metafile = {
      id = lib.mkOption {
        description = "Jagex Launcher build to install first (`launcher-win.production` in ${"https://jagex.akamaized.net/direct6/launcher-win/alias.json"})";
        type = lib.types.str;
        default = "7a43ce8eb79c9a218d52292fc975aedd83946b919f515dcb6d608a490053f618";
      };
      hash = lib.mkOption {
        description = "Hash of the files `metafile.id` lists (build with `lib.fakeHash` to get it)";
        type = lib.types.str;
        default = "sha256-90Qzjxsm3Gt+2TpBtZTlDrqCIXRmhV69ORkucy+z2o8=";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [
          launcher
          desktopItem
        ];
      }
      (lib.mkIf cfg.inhibitIdleWhileRunning {
        systemd.user.services.runelite-inhibit = {
          Unit = {
            Description = "Keep the screen awake while RuneLite is running";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = lib.getExe inhibitor;
            Restart = "on-failure";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      })
    ]
  );
}
