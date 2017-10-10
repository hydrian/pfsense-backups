#!/bin/bash -x
### Build: $Revision$
### Updated: $Date$

APPNAME=$(basename ${0}) 
## DEFAULTS
DEFCONFIG='/etc/pfsense2-backup.conf'
DEFBACKUPDIR='/var/backups/pfsense'
DEFAULT_SAVE_PACKAGE=true
DEFAULT_IGNORE_UNTRUSTED_CERTIFICATES=false

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
	
	if [ ! -z "${TMP_POSTDATA_FILE}" ] && [ -e "${TMP_POSTDATA_FILE}" ]; then
		logger -p user.debug -t "${APPNAME}" -- "Removing sensitive file ${TMP_POSTDATA_FILE}"
		rm "${TMP_POSTDATA_FILE}"
	fi
		
	
	if [ -e "${TMPAUTHFILE}" ] ; then 
		logger -p user.debug -t "${APPNAME}" -- "Removing sensitive file  ${TMPAUTHFILE}" 
		rm "${TMPAUTHFILE}"
	fi
	
	if [ -e "${PAGE_FILE}" ] ; then
		logger -p user.debug -t "${APPNAME}" -- "Removing sensitive file ${PAGE_FILE}"
		rm "${PAGE_FILE}"
	fi
}

<<<<<<< HEAD
=======
if [ ! -z "${TMP_POSTDATA_FILE}" ] && [ -e "${TMP_POSTDATA_FILE}" ]; then
	logger -p user.debug -t "${APPNAME}" -- "Removing sensitive file ${TMP_POSTDATA_FILE}"
	rm "${TMP_POSTDATA_FILE}"
fi
	

if [ -e "${TMPAUTHFILE}" ] ; then 
	logger -p user.debug -t "${APPNAME}" -- "Removing sensitive file  ${TMPAUTHFILE}" 
	rm "${TMPAUTHFILE}"
fi
return 0
}

>>>>>>> c117e2df2571981da572cb710882580369ca8546

function get_csrf {
	local PAGE_FILE="${1}"
	local CSRF_VALUE=""
	if [  ! -r "${PAGE_FILE}" ] ; then
		echo "Could not read ${PAGE_FILE}" 1>&2
		return 2
	fi 
<<<<<<< HEAD
	CSRF_VALUE=$(grep 'var csrfMagicToken = "' "${PAGE_FILE}" |sed -r 's/.*(sid\:[0-9a-f]+).*/\1/')
	if [ $? -ne 0 ] ; then
		echo "Failed to get parse CSRF out of HTML file." 1>&2
		return 3
	fi
	echo "$CSRF_VALUE"
=======
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
>>>>>>> c117e2df2571981da572cb710882580369ca8546
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

IGNORE_UNTRUSTED_CERTIFICATES="${IGNORE_UNTRUSTED_CERTIFICATES:-$DEFAULT_IGNORE_UNTRUSTED_CERTIFICATES}"

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
BACKUPFILE="pfsense-${PFSHOSTNAME}-`date +%Y%m%d%H%M%S`.xml"
touch "${BACKUPDIR}/${BACKUPFILE}"
chmod 600 "${BACKUPDIR}/${BACKUPFILE}"

if [ "${IGNORE_UNTRUSTED_CERTIFICATES,,}" == "true" ] ; then
	IGNORE_UNTRUSTED_CERTIFICAT_SET='--no-check-certificate'
else 
	IGNORE_UNTRUSTED_CERTIFICAT_SET=''	 
fi
<<<<<<< HEAD

## Get Login page
PAGE_OUTPUT=$(mktemp)
logger -p user.debug -t "${APPNAME}" -- "Getting login page..."
wget \
  --keep-session-cookies \
  --save-cookies "${COOKIEFILE}" \
  "${IGNORE_UNTRUSTED_CERTIFICAT_SET}" \
  -O "${PAGE_OUTPUT}" \
  "https://${PFSHOSTNAME}/"  1>/dev/null 2>&1 
HTTP_CALL_RET=$?
if [ ${HTTP_CALL_RET} -eq 5  ] ; then
	logger -p user.error -t "${APPNAME}" -- "SSL Verification failed"
	clean_up 
	exit 2
elif [ ${HTTP_CALL_RET} -ne 0 ] ; then
	logger -p user.error -t "${APPNAME}" -- "Failed to login page" 
	clean_up
	exit 2
fi

CSRF=$(get_csrf ${PAGE_OUTPUT})
CSRF_RET=?
rm "${PAGE_OUTPUT}"
if [ $LOGIN_CSRF_RET -ne 0 ] ; then
	logger -user.error -t "${APPNAME}" --  "Failed to get CSRF. Aborting." 
	clean_up
	exit 2
fi


## Submitting Login in to web interface
URLUSER="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${PFSUSER}")"
URLPASS="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${PFSPASS}")"
URL_CSRF="$(perl -MURI::Escape -e 'print url_escape($ARGV[0]);' "${CSRF")"

TMPAUTHFILE="$(mktemp)"
echo -n "login=Login&usernamefld=${URLUSER}&passwordfld=${URLPASS}&__csrf_magic=${URL_CSRF}" > ${TMPAUTHFILE}

=======

## Get Login page
PAGE_OUTPUT=$(mktemp)
logger -p user.debug -t "${APPNAME}" -- "Getting login page..."
wget \
  --keep-session-cookies \
  --save-cookies "${COOKIEFILE}" \
  "${IGNORE_UNTRUSTED_CERTIFICAT_SET}" \
  -O "${PAGE_OUTPUT}" \
  "https://${PFSHOSTNAME}/" 
HTTP_CALL_RET=$?
if [ ${HTTP_CALL_RET} -eq 5  ] ; then
	logger -s -p user.error -t "${APPNAME}" -- "SSL Verification failed"
	clean_up 
	exit 2
elif [ ${HTTP_CALL_RET} -ne 0 ] ; then
	logger -s -p user.error -t "${APPNAME}" -- "Failed to login page" 
	clean_up
	exit 2
fi

CSRF=$(get_csrf "${PAGE_OUTPUT}")
CSRF_RET=$?
${DEBUG,,} || rm "${PAGE_OUTPUT}"
if [ ${CSRF_RET} -ne 0 ] ; then
	logger -p user.error -t "${APPNAME}" --  "Failed to get CSRF. Aborting." 
	clean_up
	exit 2
fi


## Submitting Login in to web interface
URL_USER="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${PFSUSER}")"
URL_PASS="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${PFSPASS}")"
URL_CSRF="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${CSRF}")"

TMPAUTHFILE="$(mktemp)"
echo -n "login=Login&usernamefld=${URL_USER}&passwordfld=${URL_PASS}&__csrf_magic=${URL_CSRF}" > ${TMPAUTHFILE}

>>>>>>> c117e2df2571981da572cb710882580369ca8546
PAGE_OUTPUT=$(mktemp)
logger -p user.debug -t "${APPNAME}" -- "Submitting login credentials"
wget \
  --keep-session-cookies \
  --load-cookies ${COOKIEFILE} \
  --save-cookies ${COOKIEFILE} \
<<<<<<< HEAD
  "${IGNORE_UNTRUSTED_CERTIFICAT_SET}" \
  -O "${PAGE_OUTPUT}" \
  --post-file "${TMPAUTHFILE}" \
  "https://${PFSHOSTNAME}/index.php" 2>&1 1>/dev/null 
LOGINRES=$?
rm "${TMPAUTHFILE}"
if [ ${LOGINRES} -ne 0 ] ; then 
=======
  ${IGNORE_UNTRUSTED_CERTIFICAT_SET} \
  -O "${PAGE_OUTPUT}" \
  --post-file "${TMPAUTHFILE}" \
  https://${PFSHOSTNAME}/index.php 1>/dev/null
LOGIN_RES=$?
rm "${TMPAUTHFILE}"
if [ ${LOGIN_RES} -eq 0 ] ; then 
>>>>>>> c117e2df2571981da572cb710882580369ca8546
	logger -p user.debug -t "${APPNAME}" -- "Successfully logged in to pfSense(${PFSHOSTNAME})"
else 
	logger -p user.error -s -t "${APPNAME}" -- "Failed to logged in to pfSense(${PFSHOSTNAME})"
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

<<<<<<< HEAD
CSRF=$(get_csrf ${PAGE_OUTPUT})
CSRF_RET=?
rm "${PAGE_OUTPUT}"
if [ $LOGIN_CSRF_RET -ne 0 ] ; then
	logger -user.error -t "${APPNAME}" --  "Failed to get CSRF. Aborting." 
	clean_up
	exit 2
fi

##########################
### Downloading the Config
##########################

POSTDATA='Submit=download'
URL_CSRF="$(perl -MURI::Escape -e 'print url_escape($ARGV[0]);' "${CSRF")"
POSTDATA="${POSTDATA}&_csrf_magic=${URL_CSRF}"
if ! ${BACKUPRRD} ; then 
=======
##########################
### Downloading the Config
##########################
DOWNLOAD_VALUE="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "Download configuration as XML")"
POSTDATA="download=${DOWNLOAD_VALUE}"
URL_CSRF="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${CSRF}")"
POSTDATA="${POSTDATA}&__csrf_magic=${URL_CSRF}"
if [ "${BACKUPRRD,,}" == "true" ] ; then
	logger -p user.debug -t "${APPNAME}" -- "Enabled RRD backups" 
>>>>>>> c117e2df2571981da572cb710882580369ca8546
	POSTDATA="${POSTDATA}&donotbackuprrd=on"
fi 
if [ ! -z "${ENCRYPTPASS}" ] ; then
	logger -p user.debug -t "${APPNAME}" -- "Encrypting backup"
	URLENCRYPTPASS="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${ENCRYPTPASS}")"
<<<<<<< HEAD
	POSTDATA="${POSTDATA}&encrypt=on&encrypt_password=${URLENCRYPTPASS}&encrypt_passconf=${URLENCRYPTPASS}"
fi

### Writing POST DATA to file
TMP_POSTDATA_FILE=$(mktemp)
echo "${POSTDATA}" | tee  ${TMP_POSTDATA_FILE} 1>/dev/null
if [ $? -ne 0 ] ; then
	logger -p user.errr -s -t "${APPNAME}" -- "Failed to write POST data to temp file"
=======
	POSTDATA="${POSTDATA}&encrypt=on&encrypt_password=${URLENCRYPTPASS}&encrypt_passconf=${URLENCRYPTPASS}&"
fi
if [ "${BACKUP_PACKAGES,,}" == "true" ] ;then 
	logger -p user.debug -t "${APPNAME}" -- "Not backing up packages"
	POSTDATA="${POSTDATA}&nopackages=yes"
fi

POSTDATA_FILE=$(mktemp)
echo "${POSTDATA}" > "${POSTDATA_FILE}"

### Writing POST DATA to file
TMP_POSTDATA_FILE=$(mktemp)
echo "${POSTDATA}" | tee  ${TMP_POSTDATA_FILE} 
if [ $? -ne 0 ] ; then
	logger -p user.error -s -t "${APPNAME}" -- "Failed to write POST data to temp file"
>>>>>>> c117e2df2571981da572cb710882580369ca8546
	exit 2
fi   

## Getting backup file over HTTPS

<<<<<<< HEAD
wget 
  --keep-session-cookies \
  --load-cookies ${COOKIEFILE} \
  --save-cookies ${COOKIEFILE} \
  "${IGNORE_UNTRUSTED_CERTIFICAT_SET}" \
  -O "${BACKUPDIR}/${BACKUPFILE}" \
  --post-data "${POSTDATA}" \
  "https://${PFSHOSTNAME}/diag_backup.php" 2>&1 1>/dev/null 
=======
wget \
  --keep-session-cookies \
  --load-cookies ${COOKIEFILE} \
  --save-cookies ${COOKIEFILE} \
  ${IGNORE_UNTRUSTED_CERTIFICAT_SET} \
  -O "${BACKUPDIR}/${BACKUPFILE}" \
  --post-file="${POSTDATA_FILE}" \
  "https://${PFSHOSTNAME}/diag_backup.php" 
>>>>>>> c117e2df2571981da572cb710882580369ca8546
   
BACKUPRES=$?
rm "${POSTDATA_FILE}"
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
