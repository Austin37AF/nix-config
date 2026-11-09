# Home Manager module: `programs.wow-forever` on top of battlenet-umu.
#
# First launch of either menu entry offers to install Battle.net into the prefix; install WoW
# Forever from Battle.net and set `installDir` to wherever Battle.net put its `_forever_` folder.
#
# Addons are CurseForge files pinned by ID and hash (`curseforgeAddons`, see ./curseforge.json).
# Every Home Manager activation copies them into the game's AddOns folder; `wow-addons-update`
# bumps the pins to the newest WoW Forever release. No CurseForge API key or instawow needed:
# downloads go through the curseforge.com website's own (unofficial) download endpoint.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.wow-forever;
  driveC = "${cfg.prefix}/drive_c";
  # battlenet-umu only takes game paths relative to C:, so climb from there to installDir.
  driveCDepth = lib.length (lib.filter (c: c != "") (lib.splitString "/" driveC));
  installDirFromDriveC =
    lib.concatStrings (lib.replicate driveCDepth "../") + lib.removePrefix "/" cfg.installDir;
  cfApi = "https://www.curseforge.com/api/v1/mods";

  addonsPkg = pkgs.stdenvNoCC.mkDerivation {
    name = "wow-forever-addons";
    srcs = lib.mapAttrsToList (
      name: a:
      pkgs.fetchurl {
        name = "${name}-${toString a.fileId}.zip";
        url = "${cfApi}/${toString a.projectId}/files/${toString a.fileId}/download";
        inherit (a) hash;
      }
    ) cfg.curseforgeAddons;
    nativeBuildInputs = [ pkgs.unzip ];
    unpackPhase = ''
      mkdir -p $out
      for src in $srcs; do unzip -q -o "$src" -d $out; done
    '';
    dontInstall = true;
    dontFixup = true;
  };

  updateAddons = pkgs.writeShellApplication {
    name = "wow-addons-update";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
    ];
    text = builtins.readFile ./update-addons.sh;
  };
in
{
  options.programs.wow-forever = {
    enable = lib.mkEnableOption "WoW Forever via Battle.net and umu-launcher";
    prefix = lib.mkOption {
      description = "Wine prefix holding Battle.net and WoW";
      type = lib.types.str;
      default = "${config.xdg.dataHome}/battlenet-umu/prefix";
    };
    installDir = lib.mkOption {
      description = "Absolute path of WoW Forever's `_forever_` install folder";
      type = lib.types.str;
      default = "${driveC}/Program Files (x86)/World of Warcraft/_forever_";
    };
    exe = lib.mkOption {
      description = "WoW Forever executable, relative to `installDir`";
      type = lib.types.str;
      default = "Wow.exe";
    };
    curseforgeAddons = lib.mkOption {
      description = "CurseForge addon files to keep installed, by name (see ./curseforge.json)";
      type = lib.types.attrsOf (
        lib.types.submodule {
          freeformType = lib.types.attrsOf lib.types.anything;
          options = {
            projectId = lib.mkOption { type = lib.types.int; };
            fileId = lib.mkOption { type = lib.types.int; };
            hash = lib.mkOption { type = lib.types.str; };
          };
        }
      );
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.battlenet-umu = {
      enable = true;
      inherit (cfg) prefix;
      games = [
        { name = "Battle.net"; }
        {
          name = "WoW Forever";
          path = "${installDirFromDriveC}/${cfg.exe}";
        }
      ];
    };

    home.packages = [ updateAddons ];

    # Copies (not symlinks: Wine runs in umu's container) and tracks what it installed in
    # .nix-addons, so addons dropped from the list are removed and hand-installed ones are kept.
    # Skipped until WoW Forever is installed, so it never creates folders Battle.net expects to.
    home.activation.wowForeverAddons = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      wowRoot=${lib.escapeShellArg cfg.installDir}
      if [ -d "$wowRoot" ]; then
        addonDir="$wowRoot/Interface/AddOns"
        manifest="$addonDir/.nix-addons"
        run mkdir -p "$addonDir"
        if [ "$(head -n1 "$manifest" 2>/dev/null)" != ${addonsPkg} ]; then
          if [ -f "$manifest" ]; then
            tail -n +2 "$manifest" | while IFS= read -r folder; do
              if [ -n "$folder" ]; then run rm -rf "''${addonDir:?}/$folder"; fi
            done
          fi
          for folder in ${addonsPkg}/*; do
            run rm -rf "$addonDir/$(basename "$folder")"
            run cp -r --no-preserve=mode,ownership "$folder" "$addonDir/"
          done
          if [ -z "''${DRY_RUN:-}" ]; then
            { echo ${addonsPkg}; ls ${addonsPkg}; } > "$manifest"
          fi
          verboseEcho "WoW Forever addons installed from ${addonsPkg}"
        fi
      else
        verboseEcho "WoW Forever not installed yet, skipping addons"
      fi
    '';
  };
}
