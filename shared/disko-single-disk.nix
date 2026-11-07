# Single-disk layout (GPT: ESP + ext4 root), applied by disko at install time.
# Usage: (import ../../shared/disko-single-disk.nix { device = "/dev/sda"; })
# WARNING: installing wipes this disk. Verify the device with `lsblk` on the
# booted installer first.
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
