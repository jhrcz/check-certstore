#! /bin/bash

[ "${DEBUG}" = "YES" ] && set -x

supportedCertTypes="pem|crt|p12|jks"
exitStatus=0

BLUE='\E[34m'
RED='\E[31m'
YELLOW='\E[33m'
GREEN='\E[32m'
WHITE='\E[37m'

# reset terminal to standard colors
function resetColor
{
	tput sgr0
}
function ERROR
{
	echo "ERROR: $1" 1>&2
}

function listSupportedCertsInDir
{
	local dir=${1}
	local certFile

	pushd `pwd` > /dev/null
	cd  "$dir"
	ls | grep -E "($supportedCertTypes)"'$' | while read certFile ; do echo "${dir%/}/${certFile}" ; done
	popd > /dev/null
}

function getCertType
{
	local certFile="$1"

	certFileNameSuffix=${certFile##*.}
	case ${certFileNameSuffix} in
		pem|crt)
			echo pem
			;;
		p12)
			echo p12
			;;
		jks)
			echo jks
			;;
	esac
}


case "${1}" in
	file)
		shift
		certFiles=( "${1}" )
		;;
	dir)
		shift
		dir=${1}
		certFiles=( $( listSupportedCertsInDir ${1}) )
		;;
	*)
		ERROR "Bad arguments."
		;;
esac

echo "Checking validity of certificates:"

for certFile in "${certFiles[@]}"
do
	#echo "[cert $certFile]"
	echo -e "${BLUE}[cert $certFile]" ; resetColor
	certFileTXT="${certFile}.txt"
	if [ -f "${certFileTXT}" -a "${certFileTXT}" -nt "${certFile}" ]
	then
		certType=$(getCertType "${certFile}")
		case "${certType}" in
			pem|p12|jks)
				not_before=$(grep "Not Before" ${certFileTXT} | cut -d : -f 2- | sed -e "s#^ ##" | head -n 1 )
				not_after=$(grep "Not After" ${certFileTXT} | cut -d : -f 2-  | sed -e "s#^ ##" | head -n 1 )
				[ -n "$not_before" ] || ERROR "could not detect not-before date from cert in txt from"
				[ -n "$not_after" ] || ERROR "could not detect not-after date from cert in txt from"
				if [ -n "$not_before" -a -n "$not_after" ]
				then
					echo " type: $certType"
					issuer=$(grep "Issuer" $certFileTXT | cut -d : -f 2- | sed -e "s#^ ##" | head -n 1 )
					subject=$(grep "Subject" $certFileTXT | cut -d : -f 2-  | sed -e "s#^ ##" | head -n 1 )
					echo " subject: $subject"
					echo " issuer: $issuer"
					# convert date format YYYY-MM-DD
					not_before=$(date -d "$not_before" +%Y-%m-%d)
					not_after=$(date -d "$not_after" +%Y-%m-%d)
					echo " not-before: $not_before"
					echo " not-after: $not_after"
					# check expiration date
					if [ "$(date -d "$not_after" +%s)" -lt "$(date -d "today" +%s)" ]
					then
						exitStatus=2
						#echo " status: CRITICAL"
						echo -e " ${RED}status: CRITICAL" ; resetColor
					else
						if [ "$(date -d "$not_after" +%s)" -lt "$(date -d "today + 1 month" +%s)" ]
						then
							exitStatus=2
							#echo " status: WARNING"
							echo -e " ${YELLOW}status: WARNING" ; resetColor
						else
							#echo " status: ok"
							echo -e " ${GREEN}status: ok" ; resetColor
						fi	
					fi
				fi
				;;
		esac
	else
		exitStatus=2
		ERROR "Missing or not updated TXT form of certificate"
	fi
done

echo "[report]"
echo " status: $exitStatus"
exit $exitStatus
	
