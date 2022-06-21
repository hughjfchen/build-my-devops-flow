{ config, lib, pkgs, env, ... }:

{
  imports = [ ];

  config = lib.mkIf config.gh-webhook.enable {
    gh-webhook = {
      "command" = "Start";
      "database.host" = "${config.db.host}";
      "database.port" = config.db.port;
      "database.user" = "${config.db.dataSchemaUser}";
      "database.password" = "${config.db.dataSchemaPassword}";
      "database.database" = "${config.db.database}";
      "pool.stripe" = 1;
      "pool.idletime" = 1800;
      "pool.size" = 10;
      "oddjobsstartargs.webuiauth" = "Nothing";
      "oddjobsstartargs.webuiport" = 5555;
      "oddjobsstartargs.daemonize" = "True";
      "oddjobsstartargs.pidfile" =
        "${env.gh-webhook.runDir}/my-job-gh-webhook.pid";
      "oddjobsstopargs.timeout" = 60;
      "oddjobsstopargs.pidfile" =
        "${env.gh-webhook.runDir}/my-job-gh-webhook.pid";
      "oddjobsconfig.tablename" = "${config.db.dataSchema}.jobs";
      "oddjobsconfig.jobgh-webhook" = "";
      "oddjobsconfig.defaultmaxattempts" = 5;
      "oddjobsconfig.concurrencycontrol" = 5;
      "oddjobsconfig.dbpool" = "";
      "oddjobsconfig.pollinginterval" = 5;
      "oddjobsconfig.onjobsuccess" = "";
      "oddjobsconfig.onjobfailed" = "";
      "oddjobsconfig.onjobstart" = "";
      "oddjobsconfig.onjobtimeout" = "";
      "oddjobsconfig.pidfile" =
        "${env.gh-webhook.runDir}/my-job-gh-webhook.pid";
      "oddjobsconfig.logger" = "";
      "oddjobsconfig.jobtype" = "";
      "oddjobsconfig.jobtypesql" = "";
      "oddjobsconfig.defaultjobtimeout" = 1800;
      "oddjobsconfig.jobtohtml" = "";
      "oddjobsconfig.alljobtypes" = "";
      "cmdpath.xvfbpath" = "${pkgs.xvfb-run}/bin/xvfb-run";
      "cmdpath.wgetpath" = "${pkgs.wget}/bin/wget";
      "cmdpath.curlpath" = "${pkgs.curl}/bin/curl";
      "cmdpath.javapath" = "${pkgs.jdk11}/bin/java";
      "cmdpath.parsedumpshpath" = "${pkgs.eclipse-mat}/mat/ParseHeapDump.sh";
      "cmdpath.jcapath" = "${pkgs.my-jca.src}";
      # "cmdpath.gcmvpath" = "${pkgs.my-gcmv}/bin/gcmv";
      "cmdpath.gcmvpath" = "/usr/local/bin/gcmv";
      "outputpath.fetcheddumphome" = "${env.gh-webhook.dataDir}/raw_dump_files";
      "outputpath.jcapreprocessorhome" =
        "${env.gh-webhook.dataDir}/preprocessed_report_jca";
      "outputpath.matpreprocessorhome" =
        "${env.gh-webhook.dataDir}/preprocessed_report_mat";
      "outputpath.gcmvpreprocessorhome" =
        "${env.gh-webhook.dataDir}/preprocessed_report_gcmv";
      "outputpath.jcareporthome" =
        "${env.gh-webhook.dataDir}/parsed_report_jca";
      "outputpath.matreporthome" =
        "${env.gh-webhook.dataDir}/parsed_report_mat";
      "outputpath.gcmvreporthome" =
        "${env.gh-webhook.dataDir}/parsed_report_gcmv";
      "outputpath.jcapostprocessorhome" =
        "${env.gh-webhook.dataDir}/postprocessed_report_jca";
      "outputpath.matpostprocessorhome" =
        "${env.gh-webhook.dataDir}/postprocessed_report_mat";
      "outputpath.gcmvpostprocessorhome" =
        "${env.gh-webhook.dataDir}/postprocessed_report_gcmv";
      "jcacmdlineoptions.xmx" = 2048;
      "matcmdlineoptions.xmx" = 8192;
      "gcmvcmdlineoptions.xmx" = 2048;
      "gcmvcmdlineoptions.jvm" = "${pkgs.jdk11}";
      "gcmvcmdlineoptions.preference" =
        "${env.gh-webhook.dataDir}/default_preference.emf";
      "curlcmdlineoptions.loginuser" = "test1@test1.com";
      "curlcmdlineoptions.loginpin" = "pass1111";
      "curlcmdlineoptions.loginurl" = "http://${config.api-gw.serverName}:${
          toString config.api-gw.listenPort
        }/rest/rpc/login";
      "curlcmdlineoptions.uploadurl" = "http://${config.api-gw.serverName}:${
          toString config.api-gw.listenPort
        }/uploadreport";
    };
  };
}
