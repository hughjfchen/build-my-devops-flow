{ config, lib, pkgs, env, ... }:

{
  imports = [ ./messaging.nix ];

  config = lib.mkIf config.exe-engine.enable {
    exe-engine = {
      db-uri = ''
        "postgres://${config.db.apiSchemaUser}:${config.db.apiSchemaPassword}@${config.db.host}:${
          toString config.db.port
        }/${config.db.database}"'';
      db-schema = ''"${config.db.apiSchema}"'';
      db-anon-role = ''"${config.db.anonRole}"'';
      jwt-secret = ''"${config.db.jwtSecret}"'';
      server-host = ''"${env.exe-engine.ipAddress}"'';
      server-port = 3000;
    };
  };
}
