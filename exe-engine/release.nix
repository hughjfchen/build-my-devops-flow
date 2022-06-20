{ nativePkgs ? import ./default.nix { }, # the native package set
pkgs ? import ./cross-build.nix { }
, # the package set for corss build, we're especially interested in the fully static binary
site, # the site for release, the binary would deploy to it finally
phase, # the phase for release, must be "local", "test" and "production"
}:
let
  nPkgs = nativePkgs.pkgs;
  sPkgs = pkgs.x86-musl64; # for the fully static build
  lib = nPkgs.lib; # lib functions from the native package set
  pkgName = "my-exe-engine";
  innerTarballName = lib.concatStringsSep "." [
    (lib.concatStringsSep "-" [ pkgName site phase ])
    "tar"
    "gz"
  ];

  # define some utility function for release packing ( code adapted from setup-systemd-units.nix )
  release-utils = import ./release-utils.nix {
    inherit lib;
    pkgs = nPkgs;
  };

  # the deployment env
  my-exe-engine-env =
    (import ../env/site/${site}/phase/${phase}/env.nix { pkgs = nPkgs; }).env;

  # dependent config
  my-exe-engine-config =
    (import ../config/site/${site}/phase/${phase}/config.nix {
      pkgs = nPkgs;
      env = my-exe-engine-env;
    }).config;

  # my services dependencies
  # following define the service
  my-exe-engine-config-kv = nPkgs.writeTextFile {
    name = lib.concatStringsSep "-" [ pkgName "config" ];
    # generate the key = value format config, refer to the lib.generators for other formats
    text = (lib.generators.toKeyValue { }) my-exe-engine-config.db-gw;
  };

  # my services dependencies
  my-exe-engine-bin-sh = nPkgs.writeShellApplication {
    name = lib.concatStringsSep "-" [ pkgName "bin" "sh" ];
    runtimeInputs = [ nPkgs.haskellPackages.exe-engine ];
    text = ''
      exe-engine ${my-postgrest-config-kv} "$@"
    '';
  };

  # following define the service
  my-exe-engine-service = { lib, pkgs, config, ... }:
    let cfg = config.services.my-exe-engine;
    in {
      options = lib.attrsets.setAttrByPath [ "services" pkgName ] {
        enable = lib.mkOption {
          default = true;
          type = lib.types.bool;
          description = "enable to generate a config to start the service";
        };
        # add extra options here, if any
      };
      config = lib.mkIf cfg.enable
        (lib.attrsets.setAttrByPath [ "systemd" "services" pkgName ] {
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          description = "my exe-engine service";
          serviceConfig = {
            Type = "simple";
            User = "${my-exe-engine-env.db-gw.processUser}";
            ExecStart =
              "${my-exe-engine-bin-sh}/bin/${my-postgrest-bin-sh.name}";
            Restart = "on-failure";
          };
        });
    };

  serviceNameKey = lib.concatStringsSep "." [ pkgName "service" ];
  serviceNameUnit =
    lib.attrsets.setAttrByPath [ serviceNameKey ] mk-my-exe-engine-service-unit;

  mk-my-exe-engine-service-unit = nPkgs.writeText serviceNameKey
    (lib.attrsets.getAttrFromPath [
      "config"
      "systemd"
      "units"
      serviceNameKey
      "text"
    ] (nPkgs.nixos
      ({ lib, pkgs, config, ... }: { imports = [ my-exe-engine-service ]; })));

in rec {
  inherit nativePkgs pkgs my-exe-engine-config-kv;

  mk-my-exe-engine-service-systemd-setup-or-bin-sh =
    if my-exe-engine-env.db-gw.isSystemdService then
      (nPkgs.setupSystemdUnits {
        namespace = pkgName;
        units = serviceNameUnit;
      })
    else
      my-exe-engine-bin-sh;

  mk-my-exe-engine-service-systemd-unsetup-or-bin-sh =
    if my-exe-engine-env.db-gw.isSystemdService then
      (release-utils.unsetup-systemd-service {
        namespace = pkgName;
        units = serviceNameUnit;
      })
    else
      { };
  # following derivation just to make sure the setup and unsetup will
  # be packed into the distribute tarball.
  setup-and-unsetup-or-bin-sh = nPkgs.symlinkJoin {
    name = "my-exe-engine-setup-and-unsetup";
    paths = [
      mk-my-exe-engine-service-systemd-setup-or-bin-sh
      mk-my-exe-engine-service-systemd-unsetup-or-bin-sh
    ];
  };

  mk-my-exe-engine-reference =
    nPkgs.writeReferencesToFile setup-and-unsetup-or-bin-sh;
  mk-my-exe-engine-deploy-sh = release-utils.mk-deploy-sh {
    env = my-exe-engine-env.db-gw;
    payloadPath = setup-and-unsetup-or-bin-sh;
    inherit innerTarballName;
    execName = "exe-engine";
  };
  mk-my-exe-engine-cleanup-sh = release-utils.mk-cleanup-sh {
    env = my-exe-engine-env.db-gw;
    payloadPath = setup-and-unsetup-or-bin-sh;
    inherit innerTarballName;
    execName = "exe-engine";
  };
  mk-my-release-packer = release-utils.mk-release-packer {
    referencePath = mk-my-exe-engine-reference;
    component = pkgName;
    inherit site phase innerTarballName;
    deployScript = mk-my-exe-engine-deploy-sh;
    cleanupScript = mk-my-exe-engine-cleanup-sh;
  };

}
