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

# Server FQDN or IP.
:local sftpserver "";
# Server Account Username.
:local username "";
# Server Account Password.
:local password "";
# Server Path, leave blank to push to root. Path must exist.
:local sftppath "";
# Include date in local file names. Leave false to overwrite single files.
:local datelocal false;
# Remove local file after uploading.
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
:local dosshkeys true;
# Certificate Export
:local docertificates true;
# Certificate Password
:local certpassword "";
# User-Manager Export
:local dousermanager true;
# The Dude Export
:local dothedude true;
# User Files to export, comma-separated string or array of strings
:local userfilelist "";


### End Configuration

:local hostname [/system identity get name];
:local date [:pick [/system clock get date] 2 11];

:local lprefix "";
:if ($datelocal = true) do={
  :set lprefix ($hostname . "-" . $date . "-")
} else={
  :set lprefix ($hostname . "-")
}

:local rprefix "";
:if ($sftppath = "") do={
  :set rprefix ($hostname . "-" . $date . "-")
} else={
  :set rprefix ($sftppath . "/" . $hostname . "-" . $date . "-")
}

### SFTP Upload File
# $1 (ip,string) remote IP or FQDN
# $2 (string) username
# $3 (string) password
# $4 (string) local filename to be uploaded
# $5 (string) remote filename
:local dosftp do={
  /tool fetch address=$1 user=$2 password=$3 \
              src-path=$4 dst-path=$5 mode=sftp upload=yes
}

### SFTP Upload File(s)
# $1 (ip,string) remote IP or FQDN
# $2 (string) username
# $3 (string) password
# $4 (string,array) local file(s) to be uploaded
# string, comma-separated string, or array of strings
# $5 (string) local prefix, will be stripped from local name
# $6 (string) remote prefix, will be prepended to remote name
:local doprefixsftp do={
  :local filelist [:toarray ""];

  if ([:typeof $4] = "str") do={
    :set filelist [:toarray $2];
  }

  if ([:typeof $4] = "array") do={
    :set filelist $4;
  }

  :local index -1;
  :local rfile "";
  foreach lfile in=$filelist do={
    :set index [:find $lfile $5 -1];
    if ($index = 0) do={
      :set rfile ($6 . [:pick $lfile [:len $5] [:len $lfile]]);
    } else={
      :set rfile ($6 . $lfile);
    }
    /tool fetch address=$1 user=$2 password=$3 \
                        src-path=$lfile dst-path=$rfile mode=sftp upload=yes
  }
}

### Delete Local File(s)
# $1 (bool) usually the $removelocal variable
# $2 (string,array) local file(s) to be deleted
# string, comma-separated string, or array of strings
:local dodelete do={
  if ($1 = true) do={
    :local filelist [:toarray ""];

    if ([:typeof $2] = "str") do={
      :set filelist [:toarray $2];
    }

    if ([:typeof $2] = "array") do={
      :set filelist $2;
    }

    foreach file in=$filelist do={
      /file remove [find where name="$file"];
    }
  }
}

### Log Action
# $1 selects action text
# $2 additional message, usually the backup stage
:local dolog do={
  :local msgarr {
    start="STARTING BACKUP"; \
    create="CREATING "; \
    upload="CREATING "; \
    delete="CREATING "; \
    finish="FINISHED BACKUP" }
  }
  :local msg ($msgarr->"$1");
  :log info ("SFTP-BACKUP: " . $msg . $2);
}

:local osver [:pick [/system resource get version] 0 1];
:local boardname [/system resource get board-name];

:local logstage "";
:local cfilename "";
:local lfilename "";
:local lfilearray [:toarray ""];
:local rfilename "";

### Starting the Backup
$dolog "start";

### Binary Backup
if ($dobinbackup = true) do={
  :set cfilename ($lprefix . "backup");
  :set lfilename ($cfilename . ".backup";
  :set logstage "BINARY BACKUP";
  if ($backupencrypt = false) do={
    /system backup save name=$cfilename dont-encrypt=yes;
  } else={
    /system backup save name=$cfilename password=$backuppassword;
  }
  $dolog "upload" $logstage;
  $doprefixsftp $sftpserver $username $password $lfilename $lprefix $rprefix;
  if ($removelocal = true) do={$dolog "delete" $logstage;}
  $dodelete $removelocal $lfilename;
}

### Generic Export
if ($dogexport = true) do={
  :set cfilename ($lprefix . "export");
  :set lfilename ($cfilename . ".rsc";
  :set logstage "GENERIC EXPORT";
  if (($osver = "6" and $exportsensitive = true) or ($osver = "7" and $exportsensitive = false)) do={
    $dolog "create" $logstage;
    /export compact file=$cfilename;
  } else={
    if ($osver = "6") do={
      :set logstage ($logstage . " (hide-sensitive)");
      $dolog "create" $logstage;
      /export compact hide-sensitive file=$cfilename;
    } else={
      :set logstage ($logstage . "(show-sensitive)");
      $dolog "create" $logstage;
      /export compact show-sensitive file=$cfilename;
    }
  }
  $dolog "upload" $logstage;
  $doprefixsftp $sftpserver $username $password $lfilename $lprefix $rprefix;
  if ($removelocal = true) do={$dolog "delete" $logstage;}
  $dodelete $removelocal $lfilename;
}

### User Export
if ($douexport = true) do={
  :set cfilename ($lprefix . "user");
  :set lfilename ($cfilename . ".rsc";
  :set logstage "USER EXPORT";
  if (($osver = "6" and $exportsensitive = true) or ($osver = "7" and $exportsensitive = false)) do={
    $dolog "create" $logstage;
    /user export compact file=$cfilename;
  } else={
    if ($osver = "6") do={
      :set logstage "$logstage (hide-sensitive)";
      $dolog "create" $logstage;
      /user export compact hide-sensitive file=$cfilename;
    } else={
      :set logstage "$logstage (show-sensitive)";
      $dolog "create" $logstage;
      /user export compact show-sensitive file=$cfilename;
    }
  }
  $dolog "upload" $logstage;
  $doprefixsftp $sftpserver $username $password $lfilename $lprefix $rprefix;
  if ($removelocal = true) do={$dolog "delete" $logstage;}
  $dodelete $removelocal $lfilename;
}

### License Export
if ($dolicense = true and $boardname != "CHR") do={
  :set lfilename ([/system license get software-id] . ".key");
  :set rfilename ($rprefix . "license.key");
  :set logstage "LICENSE EXPORT";
  $dolog "create" $logstage;
  /system license output;
  $dolog "upload" $logstage;
  $dosftp $sftpserver $username $password $lfilename $rfilename
  if ($removelocal = true) do={$dolog "delete" $logstage;}
  $dodelete $removelocal $lfilename;
}

### SSH Keys
if ($dosshkeys = true) do={
  :set logstage "SSH KEY EXPORT";
  $dolog "create" $logstage;
  :set cfilename ($lprefix . "host-key");
  /ip ssh export-host-key key-file-prefix=$cfilename;
  :set lfilearray { ($cfilename . "_dsa";) \
                    ($cfilename . "_dsa.pub";) \
                    ($cfilename . "_rsa";) \
                    ($cfilename . "_rsa.pub") }
  $dolog "upload" $logstage;
  $doprefixsftp $sftpserver $username $password $lfilearray $lprefix $rprefix;
  if ($removelocal = true) do={$dolog "delete" $logstage;}
  $dodelete $removelocal $lfilearray;
}

### Certificates
if ($docertificates = true) do={
  :set logstage "CERTIFICATE EXPORT";
  $dolog "create" $logstage;
  :set lfilearray [:toarray ""];
  /certificate
  :foreach cert in=[find] do={
    :local certname [get $cert name];
    :local cfilename ($lprefix . $certname);
    export-certificate $cert file-name=$cfilename \
                       type=pkcs12 export-passphrase=$certpassword;
    :set ($lfilearray->([:len $lfilearray])) ($cfilename . ".p12");
  }
  $dolog "upload" $logstage;
  $doprefixsftp $sftpserver $username $password $lfilearray $lprefix $rprefix;
  if ($removelocal = true) do={$dolog "delete" $logstage;}
  $dodelete $removelocal $lfilearray;
}

# User-Manager
if ($dousermanager = true do={
  :set logstage "USER-MANAGER BACKUP";
  $dolog "create" $logstage;
  :set cfilename ($lprefix . "user-manager");
  :set lfilename ($cfilename . ".umb");
  $dodelete $removelocal $lfilename;
  if ($osver = "6") do={
    /tool user-manager database save name=$cfilename;
  }
  if ($osver = "7") do={
    /user-manager database save name=$cfilename;
  }
  $dolog "upload" $logstage;
  $doprefixsftp $sftpserver $username $password $lfilename $lprefix $rprefix;
  if ($removelocal = true) do={$dolog "delete" $logstage;}
  $dodelete $removelocal $lfilename;
}

# User-Manager
if ($dothedude = true) do={
  :set logstage "THE DUDE BACKUP";
  $dolog "create" $logstage;
  :set lfilename ($lprefix . "the-dude.db");
  $dodelete $removelocal $lfilename;
  /dude export-db backup-file=$lfilename;
  $dolog "upload" $logstage;
  $doprefixsftp $sftpserver $username $password $lfilename $lprefix $rprefix;
  if ($removelocal = true) do={$dolog "delete" $logstage;}
  $dodelete $removelocal $lfilename;
}

if ([:len $userfilelist] > 0) do={
  :set logstage "USER FILE BACKUP";
  $dolog "upload" $logstage;
  $doprefixsftp $sftpserver $username $password $lfilename "" $rprefix;
}

### Finishing the Backup
$dolog "finish";

### vim:set filetype=routeros:

