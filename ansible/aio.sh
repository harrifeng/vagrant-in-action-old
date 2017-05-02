apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install aptitude build-essential git ntp ntpdate openssh-server python-dev
git clone -b 14.2.2 https://git.openstack.org/openstack/openstack-ansible   /opt/openstack-ansible

export BOOTSTRAP_OPTS="bootstrap_host_data_disk_device=sdb"~
export ANSIBLE_ROLE_FETCH_MODE=git-clone
cd /opt/openstack-ansible
scripts/bootstrap-ansible.sh
scripts/bootstrap-aio.sh
cp etc/openstack_deploy/conf.d/{aodh,gnocchi,ceilometer}.yml.aio /etc/openstack_deploy/conf.d/
for f in $(ls -1 /etc/openstack_deploy/conf.d/*.aio); do mv -v ${f} ${f%.*}; done
scripts/run-playbooks.sh
