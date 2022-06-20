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

  tarball = nativePkgs.stdenv.mkDerivation {
    name = "gh-webhook-tarball";
    buildInputs = with nativePkgs; [ zip ];

    phases = [ "installPhase" ];

    installPhase = ''
      mkdir -p $out/
      zip -r -9 $out/gh-webhook-tarball.zip ${binOnly}
    '';
  };
in {
 gh-webhook-tarball = tarball;
}
) crossBuildProject
