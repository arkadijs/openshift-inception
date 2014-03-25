#!/bin/bash

ami=emi-42F235E1 # built-in CentOS EMI is no good - see README-image.md
machine=c1.xlarge
eucarc=~/.euca/eucarc
keyname=arkadi
tag=-1
domain=openshift.lan
# TODO security group 'openshift' must be pre-configured
# open inbound 22, 80, 443, DNS port 53 both TCP and UDP, all ICMP, all from the sec.group itself (just in case)
sec_group=openshift
aux_pkgs="bzip2 unzip nc tcpdump strace nano less curl wget deltarpm cloud-init"
# 600MB bootstrap due to slow download
# comment out to disable
yum_bootstrap=http://192.168.200.3/openshift-centos-packages.tar

# end of config

# fast-track to node setup
#broker_ip=192.168.100.200
#broker_internal=
#broker_internal_ip=
#bind_key=somekey==

instance="$ami -g $sec_group -k $keyname"

# really end of config


if which euca-run-instances >/dev/null && test -e $eucarc; then
  . $eucarc
else
  echo Please install euca2ools and setup $eucarc
  exit 1
fi

set -e

function extract_column() {
  awk '{print $'$1'}' < $2 | grep -Ev 0.0.0.0
}

function extract_ip() {
  host=$1
  out=$(tempfile)
  grep -E ^INSTANCE >$out
  echo ${host}_id=$(extract_column 2 $out)
  echo $host=$(extract_column 4 $out)
  echo ${host}_ip=$(extract_column 15 $out)
  echo ${host}_internal=$(extract_column 5 $out)
  echo ${host}_internal_ip=$(extract_column 16 $out)
  rm $out
}

function name_instance() {
  euca-create-tags $1 --tag Name=$2$tag
}

function wait_ip() {
  local id=$1
  local name=$2
  echo -n Waiting for IP..
  set +e
  while test -z "${!name}"; do
    sleep 10
    eval $(euca-describe-instances $id | extract_ip $name)
    echo -n .
  done
  set -e
  echo
}

function wait_node() {
  local node=$1
  local dir=${2:-/etc}
  echo Waiting for node to come up..
  set +e
  while :; do
    sleep 10
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o PasswordAuthentication=no root@$node test -d $dir && break
  done
  set -e
}

function create_instance() {
  local size=$1
  local name=$2
  shift 2
  local id=${name}_id
  eval $(euca-run-instances $instance -t $size "$@" | extract_ip $name)
  name_instance ${!id} $(echo $name | sed y/_/-/)
  wait_ip ${!id} $name
}

function cloud_config() {
  local role=$1
  local out=$(tempfile)
  sed -e "s/{{role}}/$role/" conf/cloud-config.yml >$out
  echo $out
}

repos="
rpm --import https://fedoraproject.org/static/0608B895.txt
# the image might have EPEL already enabled, thus --force
rpm -i --force http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
rpm -i http://yum.puppetlabs.com/el/6/products/i386/puppetlabs-release-6-10.noarch.rpm
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs
sed -i -re 's/(\\[puppetlabs-(products|deps)\\])/\\1\nexclude=*mcollective* activemq/' /etc/yum.repos.d/puppetlabs.repo
if test -n '$yum_bootstrap'; then
  curl -sS $yum_bootstrap | tar xpC /
  sed -i -re 's/^(keepcache).*/\1=1/' /etc/yum.conf
fi
#yum update -q -y
#restorecon -R /etc
yum install -q -y puppet libcgroup bind-utils $aux_pkgs
"

if test -z "$broker_ip"; then

broker_config=$(cloud_config broker)
create_instance $machine broker -f $broker_config
rm $broker_config

wait_node $broker
ssh root@$broker yum install -q -y bind
ssh root@$broker dnssec-keygen -a HMAC-MD5 -b 512 -n USER -r /dev/urandom -K /var/named $domain
bind_key=$(ssh root@$broker cat /var/named/K$domain'.*.key'  | awk '{print $8}')

function broker_template() {
  local out=$(tempfile)
  sed -e "s/{{broker_internal}}/$broker_internal/" broker.pp |
    sed "s/{{broker_ip}}/$broker_ip/" |
    sed "s|{{bind_key}}|$bind_key|" |
    sed "s/{{domain}}/$domain/" >$out
  echo $out
}

broker_pp=$(broker_template)
broker_bootstrap=$(tempfile)
cat >$broker_bootstrap <<EOF
set -e
$repos

mkdir /etc/openshift
puppet module install openshift/openshift_origin
puppet apply broker.pp
#yum install -q -y openshift-origin-cartridge-jbossas

oo-register-dns --domain $domain --with-node-hostname broker --with-node-ip $broker_ip
oo-register-dns --domain $domain --with-node-hostname ns1    --with-node-ip $broker_ip

sed -i -e 's/^VALID_GEAR_SIZES=.*/VALID_GEAR_SIZES="small,medium,large"/' /etc/openshift/broker.conf
sed -i -e 's/^DEFAULT_GEAR_CAPABILITIES=.*/DEFAULT_GEAR_CAPABILITIES="small,medium,large"/' /etc/openshift/broker.conf
EOF

scp $broker_pp root@$broker:broker.pp
scp $broker_bootstrap root@$broker:bootstrap.sh
ssh root@$broker sh bootstrap.sh
sh -c "ssh root@$broker reboot || exit 0"
rm $broker_pp $broker_bootstrap

# TODO setup DNS
#$aws crrs $r53_parent_zone -n $domain.     -a CREATE -t NS -l 3600 -v ns1.$domain.
#$aws crrs $r53_parent_zone -n ns1.$domain. -a CREATE -t A  -l 3600 -v $broker_ip

fi # end fast-track


node_config=$(cloud_config node)
create_instance $machine node -f $node_config
rm $node_config

function node_template() {
  local out=$(tempfile)
  sed -e "s/{{broker_internal_ip}}/$broker_internal_ip/" node.pp |
    sed "s/{{broker_internal}}/$broker_internal/" |
    sed "s|{{bind_key}}|$bind_key|" |
    sed "s/{{domain}}/$domain/" |
    sed "s/{{i}}/$i/" |
    sed "s/{{node_ip}}/$node_ip/" >$out
  echo $out
}

wait_node $node
i=1
node_pp=$(node_template)
node_bootstrap=$(tempfile)
cat >$node_bootstrap <<EOF
set -e
$repos

mkdir /etc/openshift
puppet module install openshift/openshift_origin
puppet apply node.pp
#yum install -q -y openshift-origin-cartridge-jbossas
EOF

scp $node_pp root@$node:node.pp
scp $node_bootstrap root@$node:bootstrap.sh
ssh root@$node sh bootstrap.sh
sh -c "ssh root@$node reboot || exit 0"
rm $node_pp $node_bootstrap

echo -e '\e[0;32m === fast-track params === \e[0m'
echo broker_ip=$broker_ip
echo broker_internal=$broker_internal
echo broker_internal_ip=$broker_internal_ip
echo bind_key=$bind_key

echo -e '\e[1;32m OpenShift PaaS is now ready at https://broker.'$domain'/ \e[0m'
