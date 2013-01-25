Certificate monitoring for nagios
=================================

There are many ways for monitoring certificate, many use https connection and checking certificates for this connection. I use another way, which is (i think) better for server environment and which is usable for monitoring for certificates not used for standard http connection. I could monitor any certificate which is available localy on disk.

Nice feature is, that the monitoring does not depend on the availability of the password for keystore like p12 or jks. It uses exported txt form of certificate without any sensitive data, exported by the user who knows the password. Because nagios plugins run as a unprivileged user, this brings possibility to not have the senstive key available for reading by the nagios user. This check only compares modification time of the sensitive file and the exported txt form, so the admin shoud not forget updating the txt form.

Key features of monitoring:
  * does not need direct read access to certificate
  * does not need to know cert password (needed only when generating txt form by user)
  * could monitor multicert stores like p12, jks and not only single file
  * could monitor list of cert stores defined in external file

Basic usage
-----------

```lang
command[check_cert_allindir_EXAMPLE3]=/usr/lib64/nagios/plugins/check_certstore /etc/httpd/certs/
```

Before check is directed to some certificate, txt form of the cert must be generated with
```lang
txt-from-<jks|p12|pem>.sh <path/to/cert-file>
```
This step must be run by a user who has read access to the cert file and who knows password if the certfile is password protected.

Best way to check the monitoring from commandline is with
```lang
sudo -u <nagios/nrpe user> VERBOSE=YES /usr/lib/nagios/plugins/check_certstore /srv/app/name/ssl/some_cert.jks
```

there are some options for changing the output form (by seting env variable)
  * `VERBOSE=YES` - does not print only 1 line for nagios, but prints detailed info about certificated
  * `COLORIZED_OUTPUT=YES` - enables limited colorization of the console ouput

Acknowledgement of expired certificate
--------------------------------------

There is time window, betwen you detect that the certificate will expire and you get new certificate. For this situation, monitoring supports local acknowledgement of expiration in the `${certfile}.txt.ack` file. Format of this file is:
```lang
${subject}|${issuer}|${not_after}|${ackend}
```
some real example:
```lang
C=CZ, L=Prague, O=XXX..., CN=XXX|C=US, O=Entrust.net, OU=...CN=Entrust.net Secure Server Certification Authority|2009-10-27|2012-02-01
```



Output Examples
---------------

  * status ok:
```lang
STATUS ok: ok:1 warning:0 critical:0 ERROR_MSG: WARN_MSG:
```

  * critical state when admin forgets to update the txt form:
```lang
STATUS CRITICAL: ok:0 warning:0 critical:2 ERROR_MSG:none-in-ok-state missing-or-old-txt WARN_MSG:
```

  * critical state with wrong arguments, file not readable
```lang
STATUS CRITICAL: ok:0 warning:0 critical:0 ERROR_MSG:none-in-ok-state no-certfile-specified bad-cmd-arg  WARN_MSG:dir-or-file-not-found-or-bad-perms 
```
nagios output then reports the information in this form:
```lang
...
[nagiosreport]
status ok: ok:1 warning:0 critical:0 WARN_MSG:webserver/XXXX.pem:1:ack(2012-02-01) 
```

  * output when `VERBOSE=YES` env is set

```lang
[multicert java/caetn-XXXX@XXXX.p12]
 subcerts: 1

[cert java/caetn-XXXX@XXXX.p12:1]
 type: p12
 subject: emailAddress=XXXX@XXXX.cz/UID=XXXX, CN=XXXX/serialNumber=XXXX, ...
 issuer: CN=XXXX Internal Client Authority, OU=PKI, O=XXXX, L=Prague, ST=Czech Republic, C=CZ
 not-before: 2007-01-18
 not-after: 2009-01-17
 status: ok

[nagiosreport]
STATUS CRITICAL: ok:1 warning:0 critical:0 ERROR_MSG:
```




