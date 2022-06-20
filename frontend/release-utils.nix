{ lib, pkgs, ... }:

let

  # define some utility function for release packing ( code adapted from setup-systemd-units.nix )
  mk-release-packer = { referencePath # : Path
    # paths to the corresponding reference file
    , component # : String
    # The name for the deployed component
    # e.g., "my-postgresql", "my-postgrest"
    , site # : String
    # The name for the deployed target site
    # e.g., "my-site", "local"
    , phase # : String
    # The name for the deployed target phase
    # e.g., "local", "test", "production"
    , innerTarballName # : String
    # The name for the deployed inner tarball
    # e.g., "component"+"site"+"phase".tar.gz
    , deployScript # : Path
    # the deploy script path
    , cleanupScript # : Path
    # the cleanup script path
    }:
    let
      namespace = lib.concatStringsSep "-" [ component site phase ];
      referenceKey = lib.concatStringsSep "." [ namespace "reference" ];
      reference = lib.attrsets.setAttrByPath [ referenceKey ] referencePath;
      static = pkgs.runCommand "${namespace}-reference-file-static" { } ''
        mkdir -p $out
        ${lib.concatStringsSep "\n"
        (lib.mapAttrsToList (nm: file: "ln -sv ${file} $out/${nm}") reference)}
      '';
      gen-changed-pkgs-list = name: file: ''
        oldReference=$(readlink -f "$referenceDir/${name}" || echo "$referenceDir/${name}")
        if [ -f "$oldReference" -a "$oldReference" != "${file}" ]; then
          LC_ALL=C comm -13 <(LC_ALL=C sort -u $oldReference) <(LC_ALL=C sort -u "${file}") > "$referenceDir/${name}.delta"
          fileListToPack="$referenceDir/${name}.delta"
        else
          fileListToPack="${file}"
        fi
        ln -sf "/nix/var/reference-file-static/${namespace}/${name}" \
          "$referenceDir/.${name}.tmp"
        mv -T "$referenceDir/.${name}.tmp" "$referenceDir/${name}"
      '';
    in pkgs.writeScriptBin "mk-release-packer-for-${site}-${phase}" ''
      #!${pkgs.bash}/bin/bash -e
      export PATH=${pkgs.coreutils}/bin:${pkgs.gnutar}/bin:${pkgs.gzip}/bin

      fileListToPack="${referencePath}"

      referenceDir=/nix/var/reference-file
      mkdir -p "$referenceDir"

      oldStatic=$(readlink -f /nix/var/reference-file-static/${namespace} || true)
      if [ "$oldStatic" != "${static}" ]; then
        ${
          lib.concatStringsSep "\n"
          (lib.mapAttrsToList gen-changed-pkgs-list reference)
        }
        mkdir -p /nix/var/reference-file-static
        ln -sfT ${static} /nix/var/reference-file-static/.${namespace}.tmp
        mv -T /nix/var/reference-file-static/.${namespace}.tmp /nix/var/reference-file-static/${namespace}
      else
        echo "Dependence reference file not exist or unchanged, will do a full release pack" >&2
      fi

      # pack the systemd service or executable sh and dependencies with full path
      tar zPcf ./${innerTarballName} -T "$fileListToPack"

      # pack the previous tarball and the two scripts for distribution
      packDirTemp=$(mktemp -d)
      cp "${deployScript}" $packDirTemp/deploy-${component}-to-${site}-${phase}
      cp "${cleanupScript}" $packDirTemp/cleanup-${component}-on-${site}-${phase}
      mv ./${innerTarballName}  $packDirTemp
      tar zcf ./${namespace}-dist.tar.gz \
        -C $packDirTemp \
        deploy-${component}-to-${site}-${phase} \
        cleanup-${component}-on-${site}-${phase} \
        ${innerTarballName}
      rm -fr $packDirTemp

    '';
  mk-deploy-sh =
    { env # : AttrsSet the environment for the deployment target machine
    , payloadPath # : Path the nix path to the program service or wrapping script
    , innerTarballName # : String the tarball file name for the inner package tar
    , execName # : String the executable file name
    , startCmd ? "" # : String command line to start the program, default ""
    , stopCmd ? "" # : String command line to stop the program, default ""
    }:
    pkgs.writeScript "mk-deploy-sh" ''
      #!/usr/bin/env bash

      # this script need to be run with root or having sudo permission
      [ $EUID -ne 0 ] && ! sudo -v >/dev/null 2>&1 && echo "need to run with root or sudo" && exit 127

      # some command fix up for systemd service, especially web server
      getent group nogroup > /dev/null || sudo groupadd nogroup

      # create user and group
      getent group "${env.processUser}" > /dev/null || sudo groupadd "${env.processUser}"
      getent passwd "${env.processUser}" > /dev/null || sudo useradd -m -p Passw0rd -g "${env.processUser}" "${env.processUser}"

      # create directories
      for dirToMk in "${env.runDir}" "${env.dataDir}"
      do
        if [ ! -d "$dirToMk" ]; then
           sudo mkdir -p "$dirToMk"
           sudo chown -R ${env.processUser}:${env.processUser} "$dirToMk"
        fi
      done

      # now unpack(note we should preserve the /nix/store directory structure)
      sudo tar zPxf ./${innerTarballName}
      sudo chown -R ${env.processUser}:${env.processUser} /nix

      # setup the systemd service or create a link to the executable
      ${lib.concatStringsSep "\n" (if env.isSystemdService then
        [ "sudo ${payloadPath}/bin/setup-systemd-units" ]
      else [''
        # there is a previous version here, stop it first
        if [ -e ${env.runDir}/stop.sh ]; then
          echo "stopping ${execName}"
          ${env.runDir}/stop.sh
        fi

        # since the payload path changed for every deployment,
        # the start/stop scripts must be generated each deployment
        {
          echo "#!/usr/bin/env bash"
          echo "exec ${payloadPath}/bin/${execName} ${startCmd} \"\$@\""
        } > ${env.runDir}/start.sh
        {
          echo "#!/usr/bin/env bash"
          echo "exec ${payloadPath}/bin/${execName} ${stopCmd} \"\$@\""
        } > ${env.runDir}/stop.sh
        chmod +x ${env.runDir}/start.sh ${env.runDir}/stop.sh
        echo "starting the program ${execName}"
        ${env.runDir}/start.sh
        echo "check the scripts under ${env.runDir} to start or stop the program."''])}

    '';
  mk-cleanup-sh = { env # the environment for the deployment target machine
    , payloadPath # the nix path to the program service or wrapping script
    , innerTarballName # : String the tarball file name for the inner package tar
    , execName # : String the executable file name
    }:
    pkgs.writeScript "mk-cleanup-sh" ''
      #!/usr/bin/env bash

      # this script need to be run with root or having sudo permission
      [ $EUID -ne 0 ] && ! sudo -v >/dev/null 2>&1 && echo "need to run with root or sudo" && exit 127

      # how do we unsetup the systemd unit? we do not unsetup the systemd service for now
      # we just stop it before doing the cleanup
      ${lib.concatStringsSep "\n" (if env.isSystemdService then [''
        if [ -e ${payloadPath}/bin/setup-systemd-units ]; then
           unitName=$(awk 'BEGIN { FS="\"" } /unitsToStart\+\=\(/ {print $2}' ${payloadPath}/bin/setup-systemd-units)
           sudo systemctl stop $unitName
        fi''] else
        [ "[ -e ${env.runDir}/stop.sh ] && ${env.runDir}/stop.sh" ])}

      for dirToRm in "${env.runDir}" "${env.dataDir}"
      do
        if [ -d "$dirToRm" ]; then
           sudo rm -fr "$dirToRm"
        fi
      done

      # do we need to delete the program and all its dependencies in /nix/store?
      # we do not do that for now
      # sudo rm -fr /nix/store/xxx ( maybe a file list for the package and its references )

      # well, shall we remove the user and group? maybe not
      # we do not do that for now.
      # getent passwd "${env.processUser}" > /dev/null && sudo userdel -fr "${env.processUser}"
      # getent group "${env.processUser}" > /dev/null && sudo groupdel -f "${env.processUser}"

    '';
in { inherit mk-release-packer mk-deploy-sh mk-cleanup-sh; }
{ lib, pkgs, ... }:

let

  # unsetup the systemd service
  # inspired by setup-systemd-service
  unsetup-systemd-service =
    { units # : AttrSet String (Either Path { path : Path, wanted-by : [ String ] })
    # ^ A set whose names are unit names and values are
    # either paths to the corresponding unit files or a set
    # containing the path and the list of units this unit
    # should be wanted-by (none by default).
    #
    # The names should include the unit suffix
    # (e.g. ".service")
    , namespace # : String
    # The namespace for the unit files, to allow for
    # multiple independent unit sets managed by
    # `setupSystemdUnits`.
    }:
    let
      remove-unit-snippet = name: file: ''
        oldUnit=$(readlink -f "$unitDir/${name}" || echo "$unitDir/${name}")
        if [ -f "$oldUnit" ]; then
          unitsToStop+=("${name}")
          unitFilesToRemove+=("$unitDir/${name}")
          ${
            lib.concatStringsSep "\n" (map (unit: ''
              unitWantsToRemove+=("$unitDir/${unit}.wants")
            '') file.wanted-by or [ ])
          }
        fi
      '';
    in pkgs.writeScriptBin "unsetup-systemd-units" ''
      #!${pkgs.bash}/bin/bash -e
      export PATH=${pkgs.coreutils}/bin:${pkgs.systemd}/bin

      unitDir=/etc/systemd/system
      if [ ! -w "$unitDir" ]; then
        unitDir=/nix/var/nix/profiles/default/lib/systemd/system
        mkdir -p "$unitDir"
      fi
      declare -a unitsToStop unitFilesToRemove unitWantsToRemove

      ${lib.concatStringsSep "\n"
      (lib.mapAttrsToList remove-unit-snippet units)}
      if [ ''${#unitsToStop[@]} -ne 0 ]; then
        echo "Stopping unit(s) ''${unitsToStop[@]}" >&2
        systemctl stop "''${unitsToStop[@]}"
        if [ ''${#unitWantsToRemove[@]} -ne 0 ]; then
           echo "Removing unit wants-by file(s) ''${unitWantsToRemove[@]}" >&2
           rm -fr "''${unitWantsToRemove[@]}"
        fi
        echo "Removing unit file(s) ''${unitFilesToRemove[@]}" >&2
        rm -fr "''${unitFilesToRemove[@]}"
      fi
      if [ -e /etc/systemd-static/${namespace} ]; then
         echo "removing systemd static namespace ${namespace}"
         rm -fr /etc/systemd-static/${namespace}
      fi
      systemctl daemon-reload
    '';

  # define some utility function for release packing ( code adapted from setup-systemd-units.nix )
  mk-release-packer = { referencePath # : Path
    # paths to the corresponding reference file
    , component # : String
    # The name for the deployed component
    # e.g., "my-postgresql", "my-postgrest"
    , site # : String
    # The name for the deployed target site
    # e.g., "my-site", "local"
    , phase # : String
    # The name for the deployed target phase
    # e.g., "local", "test", "production"
    , innerTarballName # : String
    # The name for the deployed inner tarball
    # e.g., "component"+"site"+"phase".tar.gz
    , deployScript # : Path
    # the deploy script path
    , cleanupScript # : Path
    # the cleanup script path
    }:
    let
      namespace = lib.concatStringsSep "-" [ component site phase ];
      referenceKey = lib.concatStringsSep "." [ namespace "reference" ];
      reference = lib.attrsets.setAttrByPath [ referenceKey ] referencePath;
      static = pkgs.runCommand "${namespace}-reference-file-static" { } ''
        mkdir -p $out
        ${lib.concatStringsSep "\n"
        (lib.mapAttrsToList (nm: file: "ln -sv ${file} $out/${nm}") reference)}
      '';
      gen-changed-pkgs-list = name: file: ''
        oldReference=$(readlink -f "$referenceDir/${name}" || echo "$referenceDir/${name}")
        if [ -f "$oldReference" -a "$oldReference" != "${file}" ]; then
          echo "$oldReference <-> ${file}"
          LC_ALL=C comm -13 <(LC_ALL=C sort -u $oldReference) <(LC_ALL=C sort -u "${file}") > "$referenceDir/${name}.delta"
          fileListToPack="$referenceDir/${name}.delta"
        else
          fileListToPack="${file}"
        fi
        ln -sf "/nix/var/reference-file-static/${namespace}/${name}" \
          "$referenceDir/.${name}.tmp"
        mv -T "$referenceDir/.${name}.tmp" "$referenceDir/${name}"
      '';
    in pkgs.writeScriptBin "mk-release-packer-for-${site}-${phase}" ''
      #!${pkgs.bash}/bin/bash -e
      export PATH=${pkgs.coreutils}/bin:${pkgs.gnutar}/bin:${pkgs.gzip}/bin

      fileListToPack="${referencePath}"

      referenceDir=/nix/var/reference-file
      mkdir -p "$referenceDir"

      oldStatic=$(readlink -f /nix/var/reference-file-static/${namespace} || true)
      if [ "$oldStatic" != "${static}" ]; then
        ${
          lib.concatStringsSep "\n"
          (lib.mapAttrsToList gen-changed-pkgs-list reference)
        }
        mkdir -p /nix/var/reference-file-static
        ln -sfT ${static} /nix/var/reference-file-static/.${namespace}.tmp
        mv -T /nix/var/reference-file-static/.${namespace}.tmp /nix/var/reference-file-static/${namespace}
      else
        echo "Dependence reference file not exist or unchanged, will do a full release pack" >&2
      fi

      # pack the systemd service or executable sh and dependencies with full path
      tar zPcf ./${innerTarballName} -T "$fileListToPack"

      # pack the previous tarball and the two scripts for distribution
      packDirTemp=$(mktemp -d)
      cp "${deployScript}" $packDirTemp/deploy-${component}-to-${site}-${phase}
      cp "${cleanupScript}" $packDirTemp/cleanup-${component}-on-${site}-${phase}
      mv ./${innerTarballName}  $packDirTemp
      tar zcf ./${namespace}-dist.tar.gz \
        -C $packDirTemp \
        deploy-${component}-to-${site}-${phase} \
        cleanup-${component}-on-${site}-${phase} \
        ${innerTarballName}
      rm -fr $packDirTemp

    '';
  mk-deploy-sh =
    { env # : AttrsSet the environment for the deployment target machine
    , payloadPath # : Path the nix path to the script which sets up the systemd service or wrapping script
    , innerTarballName # : String the tarball file name for the inner package tar
    , execName # : String the executable file name
    , startCmd ? "" # : String command line to start the program, default ""
    , stopCmd ? "" # : String command line to stop the program, default ""
    }:
    pkgs.writeScript "mk-deploy-sh" ''
      #!/usr/bin/env bash

      # this script need to be run with root or having sudo permission
      [ $EUID -ne 0 ] && ! sudo -v >/dev/null 2>&1 && echo "need to run with root or sudo" && exit 127

      # some command fix up for systemd service, especially web server
      getent group nogroup > /dev/null || sudo groupadd nogroup

      # create user and group
      getent group "${env.processUser}" > /dev/null || sudo groupadd "${env.processUser}"
      getent passwd "${env.processUser}" > /dev/null || sudo useradd -m -p Passw0rd -g "${env.processUser}" "${env.processUser}"

      # create directories
      for dirToMk in "${env.runDir}" "${env.dataDir}"
      do
        if [ ! -d "$dirToMk" ]; then
           sudo mkdir -p "$dirToMk"
           sudo chown -R ${env.processUser}:${env.processUser} "$dirToMk"
        fi
      done

      # now unpack(note we should preserve the /nix/store directory structure)
      sudo tar zPxf ./${innerTarballName}
      sudo chown -R ${env.processUser}:${env.processUser} /nix

      # setup the systemd service or create a link to the executable
      ${lib.concatStringsSep "\n" (if env.isSystemdService then
        [ "sudo ${payloadPath}/bin/setup-systemd-units" ]
      else [''
        # there is a previous version here, stop it first
        if [ -e ${env.runDir}/stop.sh ]; then
          echo "stopping ${execName}"
          ${env.runDir}/stop.sh
        fi

        # since the payload path changed for every deployment,
        # the start/stop scripts must be generated each deployment
        {
          echo "#!/usr/bin/env bash"
          echo "exec ${payloadPath}/bin/${execName} ${startCmd} \"\$@\""
        } > ${env.runDir}/start.sh
        {
          echo "#!/usr/bin/env bash"
          echo "exec ${payloadPath}/bin/${execName} ${stopCmd} \"\$@\""
        } > ${env.runDir}/stop.sh
        chmod +x ${env.runDir}/start.sh ${env.runDir}/stop.sh
        echo "starting the program ${execName}"
        ${env.runDir}/start.sh
        echo "check the scripts under ${env.runDir} to start or stop the program."''])}

    '';
  mk-cleanup-sh = { env # the environment for the deployment target machine
    , payloadPath # the nix path to the script which unsets up the systemd service or wrapping script
    , innerTarballName # : String the tarball file name for the inner package tar
    , execName # : String the executable file name
    }:
    pkgs.writeScript "mk-cleanup-sh" ''
      #!/usr/bin/env bash

      # this script need to be run with root or having sudo permission
      [ $EUID -ne 0 ] && ! sudo -v >/dev/null 2>&1 && echo "need to run with root or sudo" && exit 127

      # check to make sure we are running this cleanup script after deploy script
      alreadyDeployed=""
      ${lib.concatStringsSep "\n" (if env.isSystemdService then [''
        if [ -e ${payloadPath}/bin/unsetup-systemd-units ]; then
           alreadyDeployed="true"
        else
           alreadyDeployed="false"
        fi''] else [''
          if [ -e ${env.runDir}/start.sh ] && [ -e ${env.runDir}/stop.sh ]; then
             newBinSh=$(awk '/exec/ {print $2}' "${env.runDir}/start.sh")
             if [ -e "$newBinSh" ]; then
                alreadyDeployed="true"
             else
                alreadyDeployed="false"
             fi
          else
             alreadyDeployed="false"
          fi
        ''])}
      [ $alreadyDeployed == "false" ] && echo "service not installed yet or installed with a previous version. please run the deploy script first." && exit 126

      # ok, the deploy script had been run now we can run the cleanup script
      echo "BIG WARNING!!!"
      echo "This script will also ERASE all data generated during the program running."
      echo "That means all data generated during the program running will be lost and cannot be restored."
      echo "Think twice before you answer Y nad hit ENTER. You have been warned."
      echo "If your are looking for how to start/start the program,"
      echo "Refer to the following command"
      ${lib.concatStringsSep "\n" (if env.isSystemdService then [''
        serviceNames=$(awk 'BEGIN { FS="\"" } /unitsToStop\+\=\(/ {print $2}' ${payloadPath}/bin/unsetup-systemd-units)
        echo "To stop - sudo systemctl stop <service-name>"
        echo "To start - sudo systemctl start <service-name>"
        echo "Where <service-name> is one of $serviceNames"
      ''] else [''
        echo "To stop - ${env.runDir}/stop.sh"
        echo "To start - ${env.runDir}/start.sh"
      ''])}

      read -p "Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 129

      # how do we unsetup the systemd unit? we do not unsetup the systemd service for now
      # we just stop it before doing the cleanup
      ${lib.concatStringsSep "\n" (if env.isSystemdService then [''
        sudo ${payloadPath}/bin/unsetup-systemd-units
      ''] else
        [ "${env.runDir}/stop.sh" ])}

      for dirToRm in "${env.runDir}" "${env.dataDir}"
      do
        if [ -d "$dirToRm" ]; then
           sudo rm -fr "$dirToRm"
        fi
      done

      # do we need to delete the program and all its dependencies in /nix/store?
      # we will do that for now
      if [ -f "./${innerTarballName}" ]; then
        tar zPtvf "./${innerTarballName}"|awk '{print $NF}'|grep '/nix/store/'|awk -F'/' '{print "/nix/store/" $4}'|sort|uniq|xargs sudo rm -fr
      else
        echo "cannot find the release tarball ./${innerTarballName}, skip cleaning the distribute files."
      fi

      # well, shall we remove the user and group? maybe not
      # we will do that for now.
      getent passwd "${env.processUser}" > /dev/null && sudo userdel -fr "${env.processUser}"
      getent group "${env.processUser}" > /dev/null && sudo groupdel -f "${env.processUser}"

    '';
in {
  inherit unsetup-systemd-service mk-release-packer mk-deploy-sh mk-cleanup-sh;
}
