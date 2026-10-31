{specialArgs, ...}: {
  disko.devices.disk.main = {
    type = "disk";
    device = specialArgs.diskoDevice;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          type = "EF00";
          size = "500M";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = ["umask=0077"];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            mountOptions = ["noatime"]; # noatime option limits wear on storage
          };
        };
      };
    };
  };
}
