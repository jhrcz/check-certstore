#! /bin/bash

[ "${DEBUG}" = "YES" ] && set -x

supportedCertTypes="pem|crt|p12|jks"
exitStatus=0

function setColor
{
	case ${1} in
		blue)
			tput setf 1
			;;
		red)
			tput setf 4
			;;
		yellow)
			tput setf 3
			;;
		green)
			tput setf 2
			;;
		white)
			tput setf 7
			;;
		reset)
			tput sgr0
			;;
	esac
}

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
					setColor blue
					echo "[cert ${certFile}:${subCertIndex}]"
					setColor reset
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
							setColor red
							echo " status: CRITICAL"
							setColor reset
						else
							if [ "$(date -d "$not_after" +%s)" -lt "$(date -d "today + 1 month" +%s)" ]
							then
								exitStatus=2
								setColor yellow
								echo " status: WARNING"
								setColor reset
							else
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
	fi
done

echo "[report]"
echo " status: $exitStatus"
exit $exitStatus
	
