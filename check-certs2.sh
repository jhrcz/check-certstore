#! /bin/bash

[ "${DEBUG}" = "YES" ] && set -x

# in case of nonverbose / nagios-used run stdout is kept clean
if [ "$VERBOSE" != "YES" ]
then
	exec 3>&1
	exec 1>/tmp/check_certstore.log
fi

supportedCertTypes="pem|crt|p12|jks"
exitStatus=0
sumCritical=0
sumOK=0
sumWarning=0
COLORIZED_OUTPUT=NO
ERROR_MSG=""

function setColor
{
	case ${1} in
		blue)
			[ "$COLORIZED_OUTPUT" = "YES" ] && tput setf 1
			;;
		red)
			[ "$COLORIZED_OUTPUT" = "YES" ] && tput setf 4
			;;
		yellow)
			[ "$COLORIZED_OUTPUT" = "YES" ] && tput setf 3
			;;
		green)
			[ "$COLORIZED_OUTPUT" = "YES" ] && tput setf 2
			;;
		white)
			[ "$COLORIZED_OUTPUT" = "YES" ] && tput setf 7
			;;
		reset)
			[ "$COLORIZED_OUTPUT" = "YES" ] && tput sgr0
			;;
	esac
}

# reset terminal to standard colors
function resetColor
{
	[ "$COLORIZED_OUTPUT" = "YES" ] && tput sgr0
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

argType=""
if [ -f "${1}" ]
then
	argType=file
elif [ -d "${1}" ]
then
	argType=dir
fi

case "${argType}" in
	file)
		certFiles=( "${1}" )
		;;
	dir)
		certFiles=( $( listSupportedCertsInDir ${1}) )
		;;
	*)
		ERROR "Bad arguments."
		;;
esac

#echo "Checking validity of certificates:"

for certFile in "${certFiles[@]}"
do
	#echo "[cert $certFile]"
	echo
	setColor white
	echo "[multicert $certFile]"
	setColor reset
	multiCertFileTXT="${certFile}.txt"
	if [ -f "${multiCertFileTXT}" -a "${multiCertFileTXT}" -nt "${certFile}" ]
	then
		certType=$(getCertType "${certFile}")
		case "${certType}" in
			pem|p12|jks)
				subCertMaxIndex=$(tail -n 1 "${multiCertFileTXT}" | cut -d : -f 1)
				echo " subcerts: $subCertMaxIndex"
				for subCertIndex in $( seq 1 $subCertMaxIndex )
				do
					certFileTXT=$(mktemp)
					grep "^${subCertIndex}:" "${multiCertFileTXT}" | cut -d : -f 2- > "${certFileTXT}"
					echo
					setColor blue
					echo "[cert ${certFile}:${subCertIndex}]"
					setColor reset
					not_before=$(grep "Not Before" ${certFileTXT} | cut -d : -f 2- | sed -e "s#^ ##" | head -n 1 )
					not_after=$(grep "Not After" ${certFileTXT} | cut -d : -f 2-  | sed -e "s#^ ##" | head -n 1 )
					if [ -z "$not_before" ]
					then
						ERROR "could not detect not-before date from cert in txt from"
						ERROR_MSG="bad-txt-format $ERROR_MSG"
					fi
					if [ -z "$not_after" ]
					then
						ERROR "could not detect not-after date from cert in txt from"
						ERROR_MSG="bad-txt-format $ERROR_MSG"
					fi
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
							((sumCritical++))
							setColor red
							echo " status: CRITICAL"
							ERROR_MSG="${certFile}:${subCertIndex} $ERROR_MSG"
							setColor reset
						else
							if [ "$(date -d "$not_after" +%s)" -lt "$(date -d "today + 1 month" +%s)" ]
							then
								exitStatus=2
								((sumWarning++))
								setColor yellow
								echo " status: WARNING"
								setColor reset
							else
								((sumOK++))
								setColor green
								echo " status: ok"
								setColor reset
							fi	
						fi
					fi
					rm "${certFileTXT}"
				done
				;;
		esac
	else
		exitStatus=2
		ERROR "Missing or not updated TXT form of certificate"
		ERROR_MSG="missing-or-old-txt"
	fi
done

echo
echo "[nagiosreport]"

# in case of verbose stdout is not redirected
if [ "$VERBOSE" != "YES" ]
then
	exec 1>&3
fi

if [ -z "$ERROR_MSG" ]
then
	ERROR_MSG=none
fi

case "${exitStatus}" in
	0)
		echo "status ok: ok:$sumOK warning:$sumWarning critical:$sumCritical"
		;;
	1)
		echo "STATUS WARNING: ok:$sumOK warning:$sumWarning critical:$sumCritical"
		;;
	*)
		echo "STATUS CRITICAL: ok:$sumOK warning:$sumWarning critical:$sumCritical ERROR_MSG:$ERROR_MSG"
		;;
esac
exit $exitStatus
