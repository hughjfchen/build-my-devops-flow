{ config, lib, pkgs, env, ... }:

{
  imports = [ ./messaging.nix ];

  options = {
    exe-engine = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          To enable the config for CI/CD execuate engine,i.e., amqp-utils.
        '';
      };
      server = lib.mkOption {
        type = lib.types.str;
        default = "${config.messaging.server}";
        description = ''
          The host of the rabbitmq.
        '';
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = config.messaging.port;
        description = ''
          The port number of the rabbitmq server.
        '';
      };
      vhost = lib.mkOption {
        type = lib.types.str;
        default = "/";
        example = "/testing";
        description = ''
          The vhost for the app to connect to.
        '';
      };
      connection-name = lib.mkOption {
        type = lib.types.str;
        default = "devops-exe-engine";
        example = "";
        description = ''
          The connection name displayed in rabbitmq admin console.
        '';
      };
    };
  };
}
