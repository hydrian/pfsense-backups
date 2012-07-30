#!/bin/bash

APPNAME=$(basename ${0}) 

function display_help {
	echo "SYNTAX: ${APPNAME} -c {CONFIGFILE}"
	echo "  -c     :Location of configuration file (Default: /etc/pfsense-backup.conf)"
	echo "  -o     :Output generated file name to STDOUT"
}

function clean_up {
## Cleaning up cookie session
if [ -e ${COOKIEFILE} ] ; then
	logger user.debug -t "${APPNAME}" -- "Removing cookie file ${COOKIEFILE}" 
	rm ${COOKIEFILE}
fi

if [ -e "${TMPAUTHFILE}" ] ; then 
	logger user.debug -t "${APPNAME}" -- "Removing sensitive file  ${TMPAUTHFILE}" 
	rm "${TMPAUTHFILE}"
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


PFSCONFIG=${CLICONF:-/etc/pfsense2-backup.conf)}
##PFSUSER=''
##PFSPASS=''
##PFSHOSTNAME='pfsense'
##BACKUPDIR='/var/backups/pfsense'

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
BACKUPDIR=${BACKUPDIR:-'/var/backups/pfsense'}
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
BACKUPFILE="pfsense-${PFSHOSTNAME}-`date +%Y%m%d%H%M%S`.xml"
touch "${BACKUPDIR}/${BACKUPFILE}"
chmod 600 "${BACKUPDIR}/${BACKUPFILE}"


## Logging in to web interface
URLUSER="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${PFSUSER}")"
URLPASS="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${PFSPASS}")"
TMPAUTHFILE="$(mktemp)"
echo -n "login=Login&usernamefld=${URLUSER}&passwordfld=${URLPASS}" > ${TMPAUTHFILE}

wget -qO/dev/null --keep-session-cookies --save-cookies ${COOKIEFILE} \
 --post-file "${TMPAUTHFILE}" \
 --no-check-certificate "https://${PFSHOSTNAME}/diag_backup.php" 1> /dev/null
LOGINRES=$?
rm "${TMPAUTHFILE}"
if [ ${LOGINRES} -eq 0 ] ; then 
	logger -p user.debug -t "${APPNAME}" -- "Successfully logged in to pfSense(${PFSHOSTNAME})"
else 
	logger -p user.error -s -t "${APPNAME}" -- "Failed to logged in to pfSense(${PFSHOSTNAME})"
	clean_up
	exit 1
fi

## Getting backup file over HTTPS
wget --quiet --keep-session-cookies --load-cookies ${COOKIEFILE} \
 --post-data 'Submit=download&donotbackuprrd=yes' "https://${PFSHOSTNAME}/diag_backup.php" \
 --no-check-certificate -O "${BACKUPDIR}/${BACKUPFILE}" 
BACKUPRES=$?
if [ ${BACKUPRES} -eq 0 ] ; then 
	logger -p user.debug -t "${APPNAME}" -- "Successfully downloaded pfSense(${PFSHOSTNAME}) config file."
else 
	clean_up
	logger -p user.error -s -t "${APPNAME}" -- "Failed to download pfSense(${PFSHOSTNAME}) config file."
	exit 1
fi
	
clean_up

logger -p user.info -t "${APPNAME}" -- "Successfully completed backup of ${PFSHOSTNAME}"
OUTPUTFILENAME=${OUTPUTFILENAME:-false}
if ($OUTPUTFILENAME) ; then 
	echo "${BACKUPDIR}/${BACKUPFILE}"
fi

exit 0 
