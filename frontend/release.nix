{ nativePkgs ? import ./default.nix { }, # the native package set
pkgs ? import ./cross-build.nix { }
, # the package set for corss build, we're especially interested in the fully static binary
site , # the site for release, the binary would deploy to it finally
phase, # the phase for release, must be "local", "test" and "production"
}:
let
  nPkgs = nativePkgs.pkgs;
  sPkgs = pkgs.x86-musl64; # for the fully static build
  lib = nPkgs.lib; # lib functions from the native package set
  pkgName = "my-frontend";
  innerTarballName = lib.concatStringsSep "." [ (lib.concatStringsSep "-" [ pkgName site phase ]) "tar" "gz" ];

  # define some utility function for release packing ( code adapted from setup-systemd-units.nix )
  release-utils = import ./release-utils.nix { inherit lib; pkgs = nPkgs; };

  # the deployment env
  my-openresty-env = (import ../env/site/${site}/phase/${phase}/env.nix { pkgs = nPkgs; }).env;

  # dependent config
  my-openresty-config = (import ../config/site/${site}/phase/${phase}/config.nix { pkgs = nPkgs; env = my-openresty-env; }).config;

  # the frontend, comment out for now.
  my-frontend-distributable = (import ../frontend/default.nix { }).java-analyzer-frontend.overrideAttrs (oldAttrs:
    { buildPhase = ''
                   # following not working, do not know why
                   # rm -fr .env.production.local .env.local .env.production
                   # echo "REACT_APP_BASE_URL=http://${my-openresty-config.api-gw.serverName}:${toString my-openresty-config.api-gw.listenPort}" > .env.production
                   sed -i 's/{process.env.REACT_APP_BASE_URL}/http:\/\/${my-openresty-config.api-gw.serverName}:${toString my-openresty-config.api-gw.listenPort}/g' src/dataprovider.js
                   sed -i 's/{process.env.REACT_APP_BASE_URL}/http:\/\/${my-openresty-config.api-gw.serverName}:${toString my-openresty-config.api-gw.listenPort}/g' src/auth.js
                 '' + oldAttrs.buildPhase;
    });

in my-frontend-distributable
