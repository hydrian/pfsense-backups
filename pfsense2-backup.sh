#!/bin/bash
### Build: $Revision$
### Updated: $Date$

APPNAME=$(basename ${0}) 
## DEFAULTS
DEFAULT_CONFIG_FILE='/etc/pfsense2-backup.conf'
DEFAULT_BACKUPDIR='/var/backups/pfsense'
DEFAULT_SAVE_PACKAGE=true
DEFAULT_IGNORE_UNTRUSTED_CERTIFICATES=false
DEFAULT_DEBUG=false
DEFAULT_BACKUP_RRD=false
DEFAULT_OVERWRITE_SAVED_CONIFG=false

function display_help {
	echo "SYNTAX: ${APPNAME} -c {CONFIGFILE}"
	echo "  -c     :Location of configuration file (Default: $DEFCONFIG)"
	echo "  -o     :Output generated file name to STDOUT"
	echo "  --help :Outputs these help messages"
}

function clean_up {
## Cleaning up cookie session
	if [ -e ${COOKIEFILE} ] ; then
		logger -p user.debug -t "${APPNAME}" -- "Removing cookie file ${COOKIEFILE}" 
		${DEBUG,,} || rm ${COOKIEFILE}
	fi
	
	if [ ! -z "${TMP_POSTDATA_FILE}" ] && [ -e "${TMP_POSTDATA_FILE}" ]; then
		logger -p user.debug -t "${APPNAME}" -- "Removing sensitive file ${TMP_POSTDATA_FILE}"
		${DEBUG,,} || rm "${TMP_POSTDATA_FILE}"
	fi
		
	
	if [ -e "${TMPAUTHFILE}" ] ; then 
		logger -p user.debug -t "${APPNAME}" -- "Removing sensitive file  ${TMPAUTHFILE}" 
		${DEBUG,,} || rm "${TMPAUTHFILE}"
	fi
	
	if [ -e "${PAGE_FILE}" ] ; then
		logger -p user.debug -t "${APPNAME}" -- "Removing sensitive file ${PAGE_FILE}"
		${DEBUG,,} || rm "${PAGE_FILE}"
	fi
}


function get_csrf {
	local PAGE_FILE="${1}"
	local CSRF_VALUE=""
	if [  ! -r "${PAGE_FILE}" ] ; then
		echo "Could not read ${PAGE_FILE}" 1>&2
		return 2
	fi 

	CSRF_GREP=$(grep 'var csrfMagicToken = "' "${PAGE_FILE}") 
	if [ $? -ne 0 ] ; then
		echo "Failed to get grep CSRF out of HTML file." 1>&2
		return 3
	fi
	CSRF_VALUE=$(echo "${CSRF_GREP}"|sed -r 's/.*(sid\:[0-9a-f]+,[[:digit:]]+).*/\1/' )
	if [ $? -ne 0 ] ; then
		echo "Failed to parse CSRF out of grep statement" 1>&2
		return 4
	fi
	echo "${CSRF_VALUE}"

	return 0
}

while getopts ":c:o" opt ; do 
	case ${opt} in 
		'c')
			CLICONF="${OPTARG}"
		;;
		'o')
			OUTPUTFILENAME=true
		;;
		'--help' )
			display_help
			exit 0
		;;
		\?)
			logger -p user.error -s -t "${APPNAME}" -- "Invalid switch -${OPTARG}"
			display_help 1>&2
			exit 1
		;;		
		\:)
			logger -p user.error -s -t "${APPNAME}" -- "Invalid switch: -${opt}"
			display_help 1>&2
			exit 1
		;;
	esac
done


PFSCONFIG=${CLICONF:-$DEFAULT_CONFIG_FILE}


## Loading config file
if [ -e "${PFSCONFIG}" ] ; then 
	. "${PFSCONFIG}"
else 
	logger -p user.error -s -t ${APPNAME} -- "Could not load config file ${PFSCONFIG}"
	clean_up
	display_help 1>&2
	exit 1
fi 

### Assign unset defaults
BACKUPRRD="${BACKUPRRD:-$DEFAULT_BACKUP_RRD}"
IGNORE_UNTRUSTED_CERTIFICATES="${IGNORE_UNTRUSTED_CERTIFICATES:-$DEFAULT_IGNORE_UNTRUSTED_CERTIFICATES}"
DEBUG="${DEBUG:-$DEFAULT_DEBUG}"

## Creating backup storage directory 
BACKUPDIR=${BACKUPDIR:-$DEFAULT_BACKUPDIR}
if [ ! -d "${BACKUPDIR}" ] ; then
	mkdir -p "${BACKUPDIR}"
	if [ $? -eq 0 ] ; then 
		logger -p user.notice -s -t "${APPNAME}" -- "${APPNAME} created backup directory ${BACKUPDIR}"
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


OVERWRITE_SAVED_CONIFG=${OVERWRITE_SAVED_CONIFG:-$DEFAULT_OVERWRITE_SAVED_CONIFG}
if [ "${OVERWRITE_SAVED_CONIFG,,}" == "true" ] ; then
        BACKUPFILE="pfsense-${PFSHOSTNAME}.xml"
else
        BACKUPFILE="pfsense-${PFSHOSTNAME}-`date +%Y%m%d%H%M%S`.xml"
fi
## Create secure empty file
touch "${BACKUPDIR}/${BACKUPFILE}"
chmod 600 "${BACKUPDIR}/${BACKUPFILE}"

if [ "${IGNORE_UNTRUSTED_CERTIFICATES,,}" == "true" ] ; then
	IGNORE_UNTRUSTED_CERTIFICAT_SET='--no-check-certificate'
else 
	IGNORE_UNTRUSTED_CERTIFICAT_SET=''	 
fi

### Cookie Storage
COOKIEFILE="$(mktemp)"


## Get Login page
PAGE_OUTPUT=$(mktemp)
logger -p user.debug -t "${APPNAME}" -- "Getting login page..."
WGET_OUT=$(wget \
  --keep-session-cookies \
  --save-cookies "${COOKIEFILE}" \
  ${IGNORE_UNTRUSTED_CERTIFICAT_SET} \
  -O "${PAGE_OUTPUT}" \
  "https://${PFSHOSTNAME}/" 2>&1) 
HTTP_CALL_RET=$?
if [ ${HTTP_CALL_RET} -eq 5  ] ; then
	logger -s -p user.error -t "${APPNAME}" -- "SSL Verification failed"
	clean_up 
	exit 2
elif [ ${HTTP_CALL_RET} -ne 0 ] ; then
	logger -s -p user.error -t "${APPNAME}" -- "Failed to login page"
	echo "${WGET_OUT}"|logger -s -p user.debug -t "${APPNAME}" 
	clean_up
	exit 2
fi

CSRF=$(get_csrf "${PAGE_OUTPUT}")
CSRF_RET=$?
${DEBUG,,} || rm "${PAGE_OUTPUT}"
if [ ${CSRF_RET} -ne 0 ] ; then
	logger -s -p user.error -t "${APPNAME}" --  "Failed to get CSRF. Aborting." 
	clean_up
	exit 2
fi


## Submitting Login in to web interface
URL_USER="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${PFSUSER}")"
URL_PASS="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${PFSPASS}")"
URL_CSRF="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${CSRF}")"

TMPAUTHFILE="$(mktemp)"
echo -n "login=Login&usernamefld=${URL_USER}&passwordfld=${URL_PASS}&__csrf_magic=${URL_CSRF}" > ${TMPAUTHFILE}

PAGE_OUTPUT=$(mktemp)
logger -p user.debug -t "${APPNAME}" -- "Submitting login credentials"
WGET_OUT=$(wget \
  --keep-session-cookies \
  --load-cookies ${COOKIEFILE} \
  --save-cookies ${COOKIEFILE} \
  ${IGNORE_UNTRUSTED_CERTIFICAT_SET} \
  -O "${PAGE_OUTPUT}" \
  --post-file "${TMPAUTHFILE}" \
  https://${PFSHOSTNAME}/index.php 2>&1  )
LOGIN_RES=$?
${DEBUG,,} || rm "${TMPAUTHFILE}"
if [ ${LOGIN_RES} -eq 0 ] ; then 
	logger -p user.debug -t "${APPNAME}" -- "Successfully logged in to pfSense(${PFSHOSTNAME})"
else 
	logger -p user.error -s -t "${APPNAME}" -- "Failed to logged in to pfSense(${PFSHOSTNAME})"
	echo "${WGET_OUT}"|logger -s -p user.debug -t "${APPNAME}"
	clean_up
	exit 1
fi
#read test
CSRF=$(get_csrf ${PAGE_OUTPUT})
CSRF_RET=$?
rm "${PAGE_OUTPUT}"
if [ $CSRF_RET -ne 0 ] ; then
	logger -p user.error -t "${APPNAME}" --  "Failed to get CSRF. Aborting." 
	clean_up
	exit 2
fi

##########################
### Downloading the Config
##########################
DOWNLOAD_VALUE="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "Download configuration as XML")"
POSTDATA="download=${DOWNLOAD_VALUE}"
URL_CSRF="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${CSRF}")"
POSTDATA="${POSTDATA}&__csrf_magic=${URL_CSRF}"

### RRDs
if [ "${BACKUPRRD,,}" == "true" ] ; then
        logger -p user.info -t "${APPNAME}" -- "Enabled RRD backups"
else
        logger -p user.info -t "${APPNAME}" -- "Disabled RRD backups"
        POSTDATA="${POSTDATA}&donotbackuprrd=yes"
fi
### Encryption
if [ ! -z "${ENCRYPTPASS}" ] ; then
	logger -p user.info -t "${APPNAME}" -- "Encrypting backup"
	URLENCRYPTPASS="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${ENCRYPTPASS}")"
	POSTDATA="${POSTDATA}&encrypt=on&encrypt_password=${URLENCRYPTPASS}&encrypt_passconf=${URLENCRYPTPASS}&"
fi

### Packages
if [ "${BACKUP_PACKAGES,,}" == "true" ] ;then 
	logger -p user.info -t "${APPNAME}" -- "Backing up packages"
	POSTDATA="${POSTDATA}&nopackages=yes"
else 
   logger -p user.info -t "${APPNAME}" -- "Not backing up packages"
fi

### Writing POST DATA to file
POSTDATA_FILE=$(mktemp)
echo "${POSTDATA}" | tee  ${POSTDATA_FILE}  1>/dev/null
if [ $? -ne 0 ] ; then
	logger -p user.error -s -t "${APPNAME}" -- "Failed to write POST data to temp file"
	exit 2
fi   

## Getting backup file over HTTPS

WGET_OUT=$(wget \
  --keep-session-cookies \
  --load-cookies ${COOKIEFILE} \
  --save-cookies ${COOKIEFILE} \
  ${IGNORE_UNTRUSTED_CERTIFICAT_SET} \
  -O "${BACKUPDIR}/${BACKUPFILE}" \
  --post-file="${POSTDATA_FILE}" \
  "https://${PFSHOSTNAME}/diag_backup.php" 2>&1) 

BACKUPRES=$?
rm "${POSTDATA_FILE}"
if [ ${BACKUPRES} -eq 0 ] ; then 
	logger -p user.debug -t "${APPNAME}" -- "Successfully downloaded pfSense(${PFSHOSTNAME}) config file."
else 
	clean_up
	logger -p user.error -s -t "${APPNAME}" -- "Failed to download pfSense(${PFSHOSTNAME}) config file."
	echo "${WGET_OUT}"|logger -s -p user.debug -t "${APPNAME}" 
	exit 1
fi

if [ -z "${ENCRYPTPASS}" ] ; then
        $(head -n1 ${BACKUPDIR}/${BACKUPFILE} | grep -q '<?xml version="1.0"?>')
        IS_XMLFILE=$?
        if [ ${IS_XMLFILE} -eq 0 ] ; then
                logger -p user.debug -t "${APPNAME}" -- "Successfully checked downloaded pfSense(${PFSHOSTNAME}) config file."
        else
                clean_up
		${DEBUG,,} || rm "${BACKUPDIR}/${BACKUPFILE}"
                logger -p user.error -s -t "${APPNAME}" -- "Not correct xml pfSense(${PFSHOSTNAME}) config file."
                exit 1
        fi
fi

clean_up

logger -p user.notice -t "${APPNAME}" -- "Successfully completed backup of ${PFSHOSTNAME}"
OUTPUTFILENAME=${OUTPUTFILENAME:-false}
if ($OUTPUTFILENAME) ; then 
	echo "${BACKUPDIR}/${BACKUPFILE}"
fi

exit 0 
