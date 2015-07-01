The pfsense-backups script is designed to securely backup a pfSense router configuration and additional data. These scripts is designed to run via a cron job.

The pfsense-backups were developed for **nix/**BSD/macOS based system. These scripts should also run in Cygwin, but I know of no usage going on.

Any errors will be printed to STDERR and syslog.  If there are no errors, the script will run without any output.   Also almost all the notifications are aggregated to syslog via 'logger'.  This is to make ongoing monitoring of the script easier.