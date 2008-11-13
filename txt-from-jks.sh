#! /bin/bash
[ "$DEBUG" = "YES" ] && set -x

certFile="${1}"
#keytool -list -v -keystore "${certFile}" > ${certFile}.txt
tmpFile=$(mktemp)

keytool -list -v -storetype jks -keystore $certFile | grep "Alias name:" | cut -d : -f 2 | sed -e "s#^ ##" | while read alias
do
	keytool -export -rfc -v -alias "$alias" -storetype jks -keystore $certFile >> $tmpFile
done
$(dirname $0)/txt-from-pem.sh $tmpFile
mv $tmpFile.txt ${certFile}.txt

rm $tmpFile
