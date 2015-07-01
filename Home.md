## Description ##

The pfsense-backups script is designed to securely backup a pfSense router configuration and additional data. These scripts is designed to run via a cron job.

The pfsense-backups were developed for nix/BSD/macOS based system. These scripts should also run in Cygwin, but I know of no usage going on.

Any errors will be printed to STDERR and syslog. If there are no errors, the script will run without any output. Also almost all the notifications are aggregated to syslog via 'logger'. This is to make ongoing monitoring of the script easier.

## REQUIREMESTS ##
  * bash
  * perl with URI::Escape module
  * posix compliant logger execultable

## INSTALLATION ##
  1. Place pfsense2-backup.sh in program directory. i.e. /usr/local/bin or /opt/bin
  1. Make sure pfsense2-backup.sh is executable
  1. Copy to pfsense2-backup.example.conf to configuration location (default: /etc/pfsense2-backup.conf)
  1. **MAKE SURE PERMISSIONS OF pfsense2-backup.conf ARE SECURE.**
```
chmod 0600 ${CONFIG_FILE}
```

## CONFIGURATION ##
  * Edit configuration file
    * - Required Parameters -
      * PFSHOSTNAME='{pfSense IP/Hostname}'
        * If you are using a non-standard pfSense webConfigurator port, you can enter it here. Ex.  PFHOSTNAME='MyPFSenseBox:8443'
      * PFSUSER='{pfSense webConfigurator username}'
      * PFSPASS='{pfSense webConfigurator password}'
    * - Optional parameters -
      * BACKUPDIR='{directory to store backups}' (Default: /var/backups/pfsense)
      * BACKUPRRD=true/false (Default: false)
      * ENCRYPTPASS='Encryption passphrase' (Default: disabled)

## PARAMETERS ##
|-c|{FILE}   Location of configuration file|
|:-|:--------------------------------------|
|-o|Outputs generated backup file to STDOUT on completion. This is useful for passing off to other scripts|

## USAGE ##
  * To run: pfsense2-backup.sh -c ${CONFIGFILE}
  * Example: pfsense2-backup.sh -c /etc/pfsense2-backup.conf

## Other info ##
pfsense2-backup.sh generates files named  _pfsense-${hostname}-${date}.xml_ with in the defined BACKUPDIR directory in the configuration file.

