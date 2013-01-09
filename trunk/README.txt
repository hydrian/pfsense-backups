REQUIREMESTS
	* bash
	* perl with URI::Escape module

INSTALLATION
	1. Place pfsense2-backup.sh in program directory. i.e. /usr/local/bin or /opt/bin
	2. Make sure pfsense2-backup.sh is executable
	3. Copy to pfsense2-backup.example.conf to configuration location (default: /etc/pfsense2-backup.conf)
	4. MAKE SURE PERMISSIONS OF pfsense2-backup.conf ARE SECURE. i.e. chmod 0600
	
CONFIGURATION
	* Edit configuration file

		- Required Parameters - 
		PFSHOSTNAME='{pfSense IP/Hostname}'
		PFSUSER='{pfSense webConfigurator username}'
		PFSPASS='{pfSense webConfigurator password}'

		- Optional parameters -
		BACKUPDIR='{directory to store backups}'
		BACKUPRRD=true/false (Default: false)
		ENCRYPTPASS='Encryption passphrase' (Default: disabled)

PARAMETERS
	-c {FILE}   Location of configuration file
	-o          Outputs generated backup file to STDOUT on completion
	            This is useful for passing off to other scripts

USAGE
	To run: pfsense2-backup.sh -c ${CONFIGFILE}
	  Example: pfsense2-backup.sh -c /etc/pfsense2-backup.conf
  

