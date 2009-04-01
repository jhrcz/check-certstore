#! /bin/bash
[ "$DEBUG" = "YES" ] && set -x

certFile="${1}"

tmpFileIndexedPEM=$(mktemp)
tmpFile=$(mktemp)

# DER input
openssl x509 -in "${certFile}" -inform der -outform pem >> ${tmpFile}

certnum=0
cat ${tmpFile} | while read line2
do
	if echo "$line2" | grep -q "BEGIN CERTIFICATE"
	then
		certnum=$(expr $certnum + 1)
	fi
	echo $certnum:$line2
done  > ${tmpFileIndexedPEM}

maxSubCertIndex=$(tail -n 1 $tmpFileIndexedPEM | cut -d : -f 1 )
for subCertIndex in $( seq  1 ${maxSubCertIndex} )
do
	grep -e "^${subCertIndex}:" ${tmpFileIndexedPEM} | cut -d : -f 2 > ${tmpFileIndexedPEM}.subpem.${subCertIndex}
done

echo > ${tmpFile}
for subCertIndex in $( seq  1 ${maxSubCertIndex} )
do
	openssl x509 -in "${tmpFileIndexedPEM}.subpem.${subCertIndex}" -noout -text | sed -e "s/^/${subCertIndex}:/" >> ${tmpFile}
done

cp ${tmpFile} ${certFile}.txt

rm "${tmpFile}"
rm "${tmpFileIndexedPEM}"
rm "${tmpFileIndexedPEM}".subpem.*
