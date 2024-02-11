### RoS SFTP Backup
### Backs Up nearly everything via SFTP
#
### 2024 Leonardo Valeri Manera
#
### Based on:
# https://forum.mikrotik.com/viewtopic.php?t=159432
# https://forum.mikrotik.com/viewtopic.php?p=858564#p858564

### Configuration
#
### Set local variables. Change the value between "" to reflect your environment. Do not delete quotation marks.

# Server FQDN or IP
:local sftpserver "";
# Server Account Username
:local username "";
# Server Account Password
:local password "";
# Server Path, leave blank to push to root. Path must exist
:local sftppath "";
# Include date in local file names. Leave false to overwrite single files
:local datelocal false;
# Remove local file after uploading
:local removelocal true;
# Binary Backup
:local dobinbackup true;
# Encrypt Backup
:local backupencrypt false;
# Backup Password
:local backuppassword "";
# Sensitive information in Export
:local exportsensitive true;
# General Export
:local dogexport true;
# User Export
:local douexport true;
# License Export (not for CHR, will silently skip)
:local dolicense true;
# SSH Keys
:local dosshkeys false;
# Certificate Export
:local docertificates true;
# Certificate Password
:local certpassword "";
# User-Manager Export
:local dousermanager false;
# The Dude Export
:local dothedude false;
# User Files to export, comma-separated string or array of strings
# User Files are not removed on backup
# Any directory paths will be removed (/ -> _) on remote file
# Nonpresent files are silently skipped
:local userfilelist "autosupout.rif,autosupout.old.rif";


### End Configuration


:local hostname [/system identity get name];
:local date [:pick [/system clock get date] 2 11];

:local lprefix ($hostname . "-sftpb-");
:if ($datelocal = true) do={
  :set lprefix ($lprefix . $date . "-");
}

:local rprefix ($hostname . "-sftpb-" . $date . "-");
:if ($sftppath != "") do={
  :set rprefix ($sftppath . "/" . $rprefix);
}
:set rprefix ("/" . $rprefix);

### Process local filename to create remote filename
### Return array for file array
## Strips path separator '/' from local file name and replaces with '_'
# 'lfile' (string) the local filename
# 'lpref' (string) the local prefix to strip from start of lfile (if present)
# 'rpref' (string) remote prefix to prepend to remote filename
# 'clear' (bool) whether to delete local file after uploading
:local dofnames do={
  :local rfile "";
  :local rfilef "";

  # Strip Local Prefix if present
  if ([:find $lfile $lpref -1] = 0) do={
    :set rfile [:pick $lfile [:len $lpref] [:len $lfile]];
  } else={
    :set rfile $lfile;
  }

  # Convert / to _
  :for i from=0 to=([:len $rfile] - 1) do={
    :local char [:pick $rfile $i];
    :if ($char = "/") do={
      :set $char "_";
    }
    :set rfilef ($rfilef . $char);
  }

  # Prepend Remote Prefix
  :set rfile ($rpref . $rfilef);

  # Return array
  :return {lfile=$lfile; rfile=$rfile; clear=$clear};
}

### Delete Local File(s)
# $lfile (string) local file to be deleted
:local dodelete do={
  if ([:len [/file find where name="$lfile"]] > 0) do={
    /file remove [find where name="$lfile"];
  }
}

### Info Log Action
# $stage (string) selects action text
# $msg (string) additional message, usually the backup stage or filename
# $error (bool) (optional) creates error log instead of info if 'true'
:local dolog do={
  :local msgarr { start="STARTING BACKUP"; \
                  clear="CLEARING PREVIOUS "; \
                  create="CREATING "; \
                  upload="UPLOADING "; \
                  delete="DELETING "; \
                  user="ADDING USER FILES"; \
                  finish="FINISHED BACKUP" }
  if ($error = true) do={
    :log error ("SFTP-BACKUP: ERROR " . $msg);
  } else={
    :log info ("SFTP-BACKUP: " . ($msgarr->"$stage") . $msg);
  }
}

:local osver [:pick [/system resource get version] 0 1];
:local boardname [/system resource get board-name];

:local filesa [:toarray ""];
:local logstage "";
:local cfilename "";
:local lfilename "";
:local rfilename "";

### Starting the Backup
$dolog stage="start";

### Binary Backup
if ($dobinbackup = true) do={
  :set cfilename ($lprefix . "backup");
  :set lfilename ($cfilename . ".backup");
  :set logstage "BINARY BACKUP";
  $dolog stage="create" msg=$logstage;
  if ($backupencrypt = false) do={
    :do {
      /system backup save name=$cfilename dont-encrypt=yes;
    } on-error={$dolog stage="create" msg=$logstage error=true;}
  } else={
    :do {
      /system backup save name=$cfilename password=$backuppassword;
    } on-error={$dolog stage="create" msg=$logstage error=true;}
  }
  :set ($filesa->([:len $filesa])) \
       [$dofnames lfile=$lfilename lpref=$lprefix rpref=$rprefix clear=$removelocal];
}

### Generic Export
if ($dogexport = true) do={
  :set cfilename ($lprefix . "export");
  :set lfilename ($cfilename . ".rsc");
  :set logstage "GENERIC EXPORT";
  if (($osver = "6" and $exportsensitive = true) or ($osver = "7" and $exportsensitive = false)) do={
    $dolog stage="create" msg=$logstage;
    :do {
      /export compact file=$cfilename;
    } on-error={$dolog stage="create" msg=$logstage error=true;}
  } else={
    if ($osver = "6") do={
      $dolog stage="create" msg=($logstage . " (hide-sensitive)");
      :do {
        /export compact hide-sensitive file=$cfilename;
      } on-error={$dolog stage="create" msg=$logstage error=true;}
    } else={
      $dolog stage="create" msg=($logstage . " (show-sensitive)");
      :do {
        /export compact show-sensitive file=$cfilename;
      } on-error={$dolog stage="create" msg=$logstage error=true;}
    }
  }
  :set ($filesa->([:len $filesa])) \
       [$dofnames lfile=$lfilename lpref=$lprefix rpref=$rprefix clear=$removelocal];
}

### User Export
if ($douexport = true) do={
  :set cfilename ($lprefix . "user");
  :set lfilename ($cfilename . ".rsc");
  :set logstage "USER EXPORT";
  if (($osver = "6" and $exportsensitive = true) or ($osver = "7" and $exportsensitive = false)) do={
    $dolog stage="create" msg=$logstage;
    :do {
      /user export compact file=$cfilename;
    } on-error={$dolog stage="create" msg=$logstage error=true;}
  } else={
    if ($osver = "6") do={
      $dolog stage="create" msg=($logstage . " (hide-sensitive)");
      :do {
        /user export compact hide-sensitive file=$cfilename;
      } on-error={$dolog stage="create" msg=$logstage error=true;}
    } else={
      $dolog stage="create" msg=($logstage . " (show-sensitive)");
      :do {
        /user export compact show-sensitive file=$cfilename;
      } on-error={$dolog stage="create" msg=$logstage error=true;}
    }
  }
  :set ($filesa->([:len $filesa])) \
       [$dofnames lfile=$lfilename lpref=$lprefix rpref=$rprefix clear=$removelocal];
}

### License Export
if ($dolicense = true and $boardname != "CHR") do={
  :set logstage "LICENSE EXPORT";
  :set lfilename ([/system license get software-id] . ".key");
  :set rfilename ($rprefix . "license.key");
  $dolog stage="create" msg=$logstage;
  :do {
    /system license output;
  } on-error={$dolog stage="create" msg=$logstage error=true;}
  :set ($filesa->([:len $filesa])) \
       {lfile=$lfilename; rfile=$rfilename; clear=$removelocal};
}

### SSH Keys
if ($dosshkeys = true) do={
  :set logstage "SSH KEY EXPORT";
  :set cfilename ($lprefix . "host-key");
  $dolog stage="create" msg=$logstage;
  :do {
    /ip ssh export-host-key key-file-prefix=$cfilename;
  } on-error={$dolog stage="create" msg=$logstage error=true;}
  :foreach lfile in=[/file find where name~"^$cfilename"] do={
    :set ($filesa->([:len $filesa])) \
         [$dofnames lfile=[/file get $lfile name] lpref=$lprefix rpref=$rprefix clear=$removelocal];
  }
}

### Certificates
if ($docertificates = true) do={
  :set logstage "USER-MANAGER BACKUP";
  $dolog stage="create" msg=$logstage;
  :foreach cert in=[/certificate find] do={
    :local certname [/certificate get $cert name];
    :local cfilename ($lprefix . "cert-" . $certname);
    :do {
      /certificate export-certificate $cert file-name=$cfilename \
                                      type=pkcs12 export-passphrase=$certpassword;
    } on-error={$dolog stage="create" msg=$logstage error=true;}
    :set ($filesa->([:len $filesa])) \
         [$dofnames lfile=($cfilename . ".p12") lpref=$lprefix rpref=$rprefix clear=$removelocal];
  }
}

# User-Manager
if ($dousermanager = true) do={
  :set cfilename ($lprefix . "user-manager");
  :set lfilename ($cfilename . ".umb");
  :set logstage "USER-MANAGER BACKUP";
  $dolog stage="clear" msg=$logstage;
  :do {
    $dodelete lfile=$lfilename;
  } on-error={$dolog stage="clear" msg=$logstage error=true;}
  $dolog stage="create" msg=$logstage;
  if ($osver = "6") do={
    :do {
      /tool user-manager database save name=$cfilename;
    } on-error={$dolog stage="create" msg=$logstage error=true;}
  }
  if ($osver = "7") do={
    :do {
      /user-manager database save name=$cfilename;
    } on-error={$dolog stage="create" msg=$logstage error=true;}
  }
  :set ($filesa->([:len $filesa])) \
       [$dofnames lfile=$lfilename lpref=$lprefix rpref=$rprefix clear=$removelocal];
}

# The Dude
if ($dothedude = true) do={
  :set lfilename ($lprefix . "the-dude.db");
  :set logstage "THE DUDE BACKUP";
  $dolog stage="clear" msg=$logstage;
  :do {
    $dodelete lfile=$lfilename;
  } on-error={$dolog stage="clear" msg=$logstage error=true;}
  $dolog stage="create" msg=$logstage;
  :do {
    /dude export-db backup-file=$lfilename;
  } on-error={$dolog stage="create" msg=$logstage error=true;}
  :set ($filesa->([:len $filesa])) \
       [$dofnames lfile=$lfilename lpref=$lprefix rpref=$rprefix clear=$removelocal];
}

# User File List
if ([:len $userfilelist] > 0) do={
  $dolog stage="user";
  :foreach lfile in=[:toarray $userfilelist] do={
    :set ($filesa->([:len $filesa])) \
         [$dofnames lfile=$lfile lpref=$lprefix rpref=$rprefix clear=false];
  }
}

# Process Files Array
:local lfile "";
:local rfile "";
:local clear true;
/delay 10s;
:foreach a in=$filesa do={
  :set lfile ($a->"lfile");
  :set rfile ($a->"rfile");
  :set clear ($a->"clear");
  if ([:len [/file find where name="$lfile"]] > 0) do={
    $dolog stage="upload" msg=($lfile . " AS " . $rfile);
    :do {
      /tool fetch address=$sftpserver user=$username password=$password \
                  src-path=$lfile dst-path=$rfile mode=sftp upload=yes;
    } on-error={$dolog stage="upload" msg=$rfile error=true;}
    if ($clear = true) do={
      $dolog stage="delete" msg=$lfile;
      :do {
        $dodelete lfile=$lfile;
      } on-error={$dolog stage="delete" msg=$lfile error=true;}
    }
  }
}

### Finishing the Backup
$dolog stage="finish";

### vim:set filetype=routeros:

