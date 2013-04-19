#!/bin/bash

ldaphost=$(awk '/ipa_url/ { print $NF }' ./config.rb | sed "s/^'//g;s/'$//g;s/^\"//g;s/\"$//g;s/http[s]*/ldap/g;s/\/ipa.*//g")
ldappass=$(awk '/ipa_pass/ { print $NF }' ./config.rb | sed "s/^'//g;s/'$//g;s/^\"//g;s/\"$//g")

ldapmodify -H $ldaphost -D "cn=Directory Manager" -w "$ldappass" <<EOF
dn: uid=$1,cn=users,cn=accounts,dc=rc,dc=usf,dc=edu
changetype: modify
replace: krbPasswordExpiration
krbPasswordExpiration: $(date -d "+ 181 days" +"%Y%m%d%H%M%SZ")

EOF

exit $?
