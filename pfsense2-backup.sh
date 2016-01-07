#!/bin/bash 
### Build: $Revision$
### Updated: $Date$

APPNAME=$(basename ${0}) 
## DEFAULTS
DEFCONFIG='/etc/pfsense2-backup.conf'
DEFBACKUPDIR='/var/backups/pfsense'


function display_help {
	echo "SYNTAX: ${APPNAME} -c {CONFIGFILE}"
	echo "  -c     :Location of configuration file (Default: $DEFCONFIG)"
	echo "  -o     :Output generated file name to STDOUT"
}

function clean_up {
## Cleaning up cookie session
if [ -e ${COOKIEFILE} ] ; then
	logger -p user.debug -t "${APPNAME}" -- "Removing cookie file ${COOKIEFILE}" 
	rm ${COOKIEFILE}
fi

}

while getopts ":c:o" opt ; do 
	case ${opt} in 
		'c')
			CLICONF="${OPTARG}"
		;;
		'o')
			OUTPUTFILENAME=true
		;;
		\?)
			logger -p user.error -s -t "${APPNAME}" -- "Invalid switch -${OPTARG}"
			display_help
			exit 1
		;;		
		\:)
			logger -p user.error -s -t "${APPNAME}" -- "Invalid switch: -${opt}"
			display_help
			exit 1
		;;
	esac
done


PFSCONFIG=${CLICONF:-$DEFCONFIG}
##PFSUSER=''
##PFSPASS=''
##PFSHOSTNAME='pfsense'
##BACKUPDIR='/var/backups/pfsense'
##BACKUPRRDDATA=1

COOKIEFILE="$(mktemp)"

## Loading config file
if [ -e "${PFSCONFIG}" ] ; then 
	. "${PFSCONFIG}"
else 
	logger -p user.error -s -t ${APPNAME} -- "Could not load config file ${PFSCONFIG}"
	clean_up
	display_help
	exit 1
fi 

## Creating backup storage directory 
BACKUPDIR=${BACKUPDIR:-$DEFBACKUPDIR}
if [ ! -d "${BACKUPDIR}" ] ; then
	mkdir -p "${BACKUPDIR}"
	if [ $? -eq 0 ] ; then 
		logger -p user.notice -s -t ${APPNAME} -- "${APPNAME} created backup directory ${BACKUPDIR}"
	else
		clean_up
		logger -p user.error -s -t "${APPNAME}" -- "Could not create backup storage directory ${BACKUPDIR}"
		exit 1
	fi
fi

## Test if require parameters are set
if [ -z "${PFSUSER}" ] || [ -z "${PFSPASS}" ] || [ -z "${PFSHOSTNAME}" ] ; then 
	logger -p user.error -s -t "${APPNAME}" -- "Make sure the PFSHOSTNAME, PFSUSER, PFSPASS are defined the configuration file."
	display_help
	clean_up
	exit 1
fi


## Create secure empty file
BACKUPFILE="pfsense-`echo ${PFSHOSTNAME} | sed -e "s/[^/]*\/\/\([^@]*@\)\?\([^:/]*\).*/\2/"`-`date +%Y%m%d%H%M%S`.xml"
touch "${BACKUPDIR}/${BACKUPFILE}"
chmod 600 "${BACKUPDIR}/${BACKUPFILE}"

## Logging in to web interface
URLUSER="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${PFSUSER}")"
URLPASS="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${PFSPASS}")"
AUTHDATA="login=Login&usernamefld=${URLUSER}&passwordfld=${URLPASS}"

# As per https://doc.pfsense.org/index.php/Remote_Config_Backup#2.2.6_and_Later get CSRF first
CSRF1=$(wget -qO- --keep-session-cookies --save-cookies ${COOKIEFILE} \
  --no-check-certificate "${PFSHOSTNAME}/diag_backup.php" \
    | grep "name='__csrf_magic'" | sed 's/.*value="\(.*\)".*/\1/')

CSRF2=$(wget -qO- --keep-session-cookies --load-cookies ${COOKIEFILE} \
  --save-cookies ${COOKIEFILE} --no-check-certificate \
    --post-data "${AUTHDATA}&__csrf_magic=${CSRF1}" \
      "${PFSHOSTNAME}/diag_backup.php" | grep "name='__csrf_magic'" \
        | sed 's/.*value="\(.*\)".*/\1/')

LOGINRES=$?
if [ ${LOGINRES} -eq 0 ] ; then 
	logger -p user.debug -t "${APPNAME}" -- "Successfully logged in to pfSense (${PFSHOSTNAME})"
else 
	logger -p user.error -s -t "${APPNAME}" -- "Failed to login to pfSense (${PFSHOSTNAME})"
	clean_up
	exit 1
fi

POSTDATA="Submit=download&__csrf_magic=${CSRF2}"
if ! ${BACKUPRRD} ; then 
	POSTDATA="${POSTDATA}&donotbackuprrd=on"
fi 
if [ ! -z "${ENCRYPTPASS}" ] ; then
	URLENCRYPTPASS="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${ENCRYPTPASS}")"
	POSTDATA="${POSTDATA}&encrypt=on&encrypt_password=${URLENCRYPTPASS}&encrypt_passconf=${URLENCRYPTPASS}"
fi 

## Getting backup file over HTTPS
wget --quiet --keep-session-cookies --load-cookies ${COOKIEFILE} \
 --post-data "${POSTDATA}" "${PFSHOSTNAME}/diag_backup.php" \
 --no-check-certificate -O "${BACKUPDIR}/${BACKUPFILE}" 
BACKUPRES=$?
if [ ${BACKUPRES} -eq 0 ] ; then 
	logger -p user.debug -t "${APPNAME}" -- "Successfully downloaded pfSense (${PFSHOSTNAME}) config file."
else 
	clean_up
	logger -p user.error -s -t "${APPNAME}" -- "Failed to download pfSense (${PFSHOSTNAME}) config file."
	exit 1
fi
	
clean_up

logger -p user.info -t "${APPNAME}" -- "Successfully completed backup of ${PFSHOSTNAME}"
OUTPUTFILENAME=${OUTPUTFILENAME:-false}
if ($OUTPUTFILENAME) ; then 
	echo "${BACKUPDIR}/${BACKUPFILE}"
fi

exit 0 
