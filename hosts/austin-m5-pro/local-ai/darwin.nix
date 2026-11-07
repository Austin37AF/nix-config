# Local AI tooling for macOS (LM Studio + Zed + nvtop)
# LM Studio and Zed come from Homebrew casks: Zed isn't cached for aarch64-darwin
# in nixpkgs (long Rust build), and casks track upstream releases more closely.
{ pkgs, ... }: {
  environment.systemPackages = [ pkgs.nvtopPackages.apple ];

  homebrew.casks = [
    "lm-studio"
    "zed"
  ];
}
