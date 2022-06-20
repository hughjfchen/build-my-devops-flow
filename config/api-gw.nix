{ config, lib, pkgs, env, ... }:

{
  imports = [ ./db-gw.nix ];

  options = {
    api-gw = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          To enable the config for the API Gateway, i.e., openresty.
        '';
      };
      docRoot = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/var/openresty/web";
        description = ''
          The document root path for openresty web content.
        '';
      };
      uploadHome = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "${env.api-gw.runDir}/upload";
        example = "/var/openresty/run/upload";
        description = ''
          The path for openresty web upload content.
        '';
      };
      logDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "${env.api-gw.runDir}/log";
        example = "/var/openresty/run/log";
        description = ''
          The path for openresty logging.
        '';
      };
      cacheDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "${env.api-gw.runDir}/cache";
        example = "/var/openresty/run/cache";
        description = ''
          The path for openresty caching.
        '';
      };
      serverName = lib.mkOption {
        type = lib.types.str;
        default = "${env.api-gw.dnsName}";
        example = "myserver";
        description = ''
          The server name for the api service.
          Clients will use this name to access the api
          so it should be resolved by DNS.
        '';
      };
      listenPort = lib.mkOption {
        type = lib.types.int;
        default = 80;
        example = 8880;
        description = ''
          The port number to listen on.
        '';
      };
      uploadMaxSize = lib.mkOption {
        type = lib.types.str;
        default = "1024M";
        example = "1024M";
        description = ''
          The max size for upload file.
        '';
      };
      resolver = lib.mkOption {
        type = lib.types.str;
        default = "local=on";
        example = "local=on";
        description = ''
          Resolver for nginx/openresty, default to local, i.e.,
          use the /etc/resolve.conf on the host machine.
        '';
      };
      postgrest-host = lib.mkOption {
        type = lib.types.str;
        default = "${config.db-gw.server-host}";
        example = "127.0.0.1";
        description = ''
          The DNS name or IP address for the backend postgrest service.
          Note this is DNS name, not host name, so It's strongly
          recommended using IP address instead of host name.
        '';
      };
      postgrest-port = lib.mkOption {
        type = lib.types.int;
        default = "${config.db-gw.server-port}";
        example = 3000;
        description = ''
          Resolver for nginx/openresty, default to local, i.e.,
          use the /etc/resolve.conf on the host machine.
        '';
      };
    };
  };
}
