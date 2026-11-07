# Home Manager module: `programs.wow-forever` on top of battlenet-umu.
#
# First launch of either menu entry offers to install Battle.net into the prefix (keep the
# default install location); install WoW Forever from Battle.net, then launch "WoW Forever".
# Addons sync on every rebuild/boot (`sync-addons forever` to run by hand);
# update them with `instawow -p forever update`.
{ config, lib, ... }:
let
  cfg = config.programs.wow-forever;
  wowDir = "Program Files (x86)/World of Warcraft/_forever_";
in
{
  options.programs.wow-forever = {
    enable = lib.mkEnableOption "WoW Forever via Battle.net and umu-launcher";
    prefix = lib.mkOption {
      description = "Wine prefix holding Battle.net and WoW";
      type = lib.types.str;
      default = "${config.xdg.dataHome}/battlenet-umu/prefix";
    };
    exe = lib.mkOption {
      description = "WoW Forever executable, relative to the `_forever_` install folder";
      type = lib.types.str;
      default = "WowClassic.exe";
    };
    addons = lib.mkOption {
      description = "instawow addon specs to keep installed";
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "github:Questie/Questie" "curse:details" ];
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
          path = "${wowDir}/${cfg.exe}";
        }
      ];
      addons = {
        enable = true;
        versions = [
          {
            name = "forever";
            addonDir = "${wowDir}/Interface/AddOns";
            flavour = "forever_classic";
            inherit (cfg) addons;
          }
        ];
      };
    };
  };
}
