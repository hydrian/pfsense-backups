REQUIREMESTS
	* bash
	* perl with URI::Escape module
	* posix compliant logger executable
	* wget

INSTALLATION
	1. Place pfsense2-backup.sh in program directory. i.e. /usr/local/bin or /opt/bin
	2. Make sure pfsense2-backup.sh is executable
	3. Copy to pfsense2-backup.example.conf to configuration location (default: /etc/pfsense2-backup.conf)
	4. MAKE SURE PERMISSIONS OF pfsense2-backup.conf ARE SECURE. i.e. chmod 0600
	
CONFIGURATION
	* Edit configuration file

		- Required Parameters - 
		PFSHOSTNAME='{pfSense IP/Hostname:pfSenseWebConfPort}'
		If you are using a non-standard pfSense admin webConfigurator port, you can enter it here.
		Ex.  PFHOSTNAME='MyPFSenseBox:8443'

		PFSUSER='{pfSense webConfigurator username}'

		PFSPASS='{pfSense webConfigurator password}'

		- Optional parameters -
		BACKUPDIR='{directory to store backups}' (Default: /var/backups/pfense)
		BACKUPRRD=true/false (Default: false)
		ENCRYPTPASS='Encryption passphrase' (Default: disabled)
		DEBUG=true/false (Default: false)
			DO NOT ENABLE THIS LIGHTLY. THE OPTION CAN LEAVE SENSITIVE DATA IN TEMP FILES LAYING AROUND.
		

PARAMETERS
	-c {FILE}   Location of configuration file
	-o          Outputs generated backup file to STDOUT on completion
	            This is useful for passing off to other scripts
	--help      Displays help messages

USAGE
	To run: pfsense2-backup.sh -c ${CONFIGFILE}
	  Example: pfsense2-backup.sh -c /etc/pfsense2-backup.conf
  
BEST PRACTICES
	Create a pfSense user that is only authorized to 'Diagnostics: Backup & Restore' permissions
