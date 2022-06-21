{ config, lib, pkgs, ... }:
let envSubM = import ../../../../env.nix { inherit config lib pkgs; };
in {
  imports = [ ];

  options = {
    exe-engine = lib.mkOption {
      type = lib.types.submodule envSubM;
      description = ''
        The deploy target host env.
      '';
    };
  };

  config = {
    exe-engine = rec {
      hostName = "localhost";
      dnsName = "localhost";
      ipAddress = "127.0.0.1";
      processUser = "doexeengineuser";
      isSystemdService = true;
      runDir = "/var/${processUser}/run";
      dataDir = "/var/${processUser}/data";
    };
  };
}
