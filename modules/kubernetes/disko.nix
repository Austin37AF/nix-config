# Disk layout for K8s nodes (applied by nixos-anywhere via disko)
# WARNING: nixos-anywhere wipes this disk. Verify the device with `lsblk` on the
# booted installer before deploying; override per node in cluster-config.nix.
{ device }:
{
  disko.devices.disk.main = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          type = "EF00";
          size = "512M";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
