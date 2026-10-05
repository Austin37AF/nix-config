# Zed configured for pair programming and PR review against local LM Studio (Qwen3.6-27B)
#
# One-time model download (after launching LM Studio once to bootstrap `lms`):
#   lms get qwen/qwen3.6-27b     # choose the MLX 6-bit variant when prompted
#   lms server start
# In LM Studio, load the model with a context length of 65536 (default is 4096).
#
# PR review: switch the Agent panel to the "Review" profile and run /pr-review
# (optionally with a PR number, e.g. "/pr-review 123").
{ pkgs, lib, ... }:
let
  model = "qwen/qwen3.6-27b";
in
{
  # `lms` CLI is installed by LM Studio into ~/.lmstudio/bin
  home.sessionPath = [ "$HOME/.lmstudio/bin" ];

  # Global agent skills (loaded by Zed from ~/.agents/skills)
  home.file.".agents/skills/pr-review".source = ./skills/pr-review;

  programs.zed-editor = {
    enable = true;
    # macOS: installed via Homebrew cask (modules/local-ai/darwin.nix)
    package = lib.mkIf pkgs.stdenv.isDarwin null;
    extensions = [ "nix" ];
    userSettings = {
      telemetry = { diagnostics = false; metrics = false; };
      buffer_font_family = "JetBrainsMono Nerd Font";
      terminal.font_family = "JetBrainsMono Nerd Font";
      language_models.lmstudio = {
        api_url = "http://localhost:1234/api/v0";
        available_models = [{
          name = model;
          display_name = "Qwen3.6 27B (local)";
          max_tokens = 65536;
          supports_tool_calls = true;
          supports_images = true;
        }];
      };
      agent = {
        default_model = { provider = "lmstudio"; inherit model; };
        profiles.review = {
          name = "Review";
          # Read-only plus terminal (for git/gh diff); no file edits
          tools = {
            read_file = true;
            grep = true;
            find_path = true;
            list_directory = true;
            diagnostics = true;
            skill = true;
            terminal = true;
            edit_file = false;
            write_file = false;
            delete_path = false;
            move_path = false;
            copy_path = false;
            create_directory = false;
          };
          enable_all_context_servers = false;
          context_servers = { };
        };
      };
    };
  };
}
