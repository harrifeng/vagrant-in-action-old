sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install aptitude build-essential git ntp ntpdate openssh-server python-dev
sudo git clone -b 14.2.2 https://git.openstack.org/openstack/openstack-ansible   /opt/openstack-ansible
sudo cd /opt/openstack-ansible

export BOOTSTRAP_OPTS="bootstrap_host_data_disk_device=sdb"~
export ANSIBLE_ROLE_FETCH_MODE=git-clone
scripts/bootstrap-ansible.sh
scripts/bootstrap-aio.sh
scripts/run-playbooks.sh
