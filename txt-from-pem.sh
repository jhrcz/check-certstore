#! /bin/bash
[ "$DEBUG" = "YES" ] && set -x

certFile="${1}"
openssl x509 -in "${certFile}" -noout -text > ${certFile}.txt

