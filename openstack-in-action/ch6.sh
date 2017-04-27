# update the package we use mirror 163
# sudo apt-get update

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install vlan bridge-utils

SYSCTL_CONF=/etc/sysctl.conf

echo "
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0" | sudo tee -a ${SYSCTL_CONF}

# enable the changes
sudo sysctl -p
