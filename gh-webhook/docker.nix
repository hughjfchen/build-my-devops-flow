{ nativePkgs ? (import ./default.nix {}).pkgs,
crossBuildProject ? import ./cross-build.nix {} }:
nativePkgs.lib.mapAttrs (_: prj:
with prj.gh-webhook;
let
  executable = gh-webhook.java-analyzer-runner.components.exes.java-analyzer-runner;
  binOnly = prj.pkgs.runCommand "gh-webhook-bin" { } ''
    mkdir -p $out/bin
    cp ${executable}/bin/gh-webhook $out/bin
    ${nativePkgs.nukeReferences}/bin/nuke-refs $out/bin/gh-webhook
  '';
in { 
  gh-webhook-image = prj.pkgs.dockerTools.buildImage {
  name = "gh-webhook";
  tag = executable.version;
  contents = [ binOnly prj.pkgs.cacert prj.pkgs.iana-etc ];
  config.Entrypoint = "gh-webhook";
  config.Cmd = "--help";
  };
}) crossBuildProject
