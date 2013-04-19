#!/bin/bash

groupbase="cn=groups,cn=accounts,dc=rc,dc=usf,dc=edu"
ldaphost=$(awk '/ipa_url/ { print $NF }' ./config.rb | sed "s/'//g;s/\"//g;s/http[s]*/ldap/g;s/\/ipa.*//g")

ldapsearch="ldapsearch -LLL -H ${ldaphost} -b ${groupbase} -x"

# get list of LDAP groups
groups=$($ldapsearch cn description | awk '/^cn:/ { cn=$NF } /^description:/ && /{[ ]*:(owner|desc)/ { print cn }')
acls=$(qconf -sul)

for group in $groups; do
  members=$($ldapsearch cn=$group member | awk '/^member:/ { print $NF }' | sed 's/uid=//g;s/\,.*$//g')

  [ -z "$members" ] && continue  

  if [[ "$acls" =~ "$group" ]]; then
    qconf -su $group | sed -n '/entries/q;p' > /tmp/.${group}.sge_ul.$$
    echo "entries $(echo $members | sed 's/ /\,/g')" >> /tmp/.${group}.sge_ul.$$
    qconf -Mu /tmp/.${group}.sge_ul.$$
  else
    cat > /tmp/.${group}.sge_ul.$$ <<EOF
name    $group
type    ACL DEPT
fshare  100
oticket 0
entries $(echo $members | sed 's/ /\,/g')
EOF
    qconf -Au /tmp/.${group}.sge_ul.$$
  fi
  rm -f /tmp/.${group}.sge_ul.$$
done

