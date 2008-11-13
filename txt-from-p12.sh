#! /bin/bash
[ "$DEBUG" = "YES" ] && set -x

certFile="${1}"
#keytool -list -v -keystore "${certFile}" > ${certFile}.txt
tmpFile=$(mktemp)

openssl pkcs12 -in $certFile -clcerts -nokeys -out $tmpFile

$(dirname $0)/txt-from-pem.sh ${tmpFile}
cp ${tmpFile}.txt ${certFile}.txt

rm ${tmpFile}
rm ${tmpFile}.txt