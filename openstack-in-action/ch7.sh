# update the package we use mirror 163
sudo apt-get update

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install lvm2

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install cinder-volume


CINDER_CONF=/etc/cinder/cinder.conf
echo "
[DEFAULT]
iscsi_helper = tgtadm
volume_group = cinder-volumes
rpc_backend = cinder.openstack.common.rpc.impl_kombu
rabbit_host = 192.168.2.50
rabbit_password = guest
glance_host = 192.168.2.50

[database]
connection = mysql://cinder_dbu:openstack1@192.168.2.50/cinder
[keystone_authtoken]
auth_uri = http://10.33.2.50:35357/v2.0
admin_tenant_name = service
admin_password = openstack1
auth_protocol = http
admin_user = cinder" | sudo tee -a ${CINDER_CONF}

sudo service cinder-volume restart
sudo service tgt restart
sudo apt-get install -y python-cinderclient

echo "----------------"
cinder --os-username admin \
       --os-password openstack1 \
       --os-tenant-name admin \
       --os-auth-url http://10.33.2.50:35357/v2.0 \
       list

cinder  --os-username admin \
        --os-password openstack1 \
        --os-tenant-name admin \
        --os-auth-url http://10.33.2.50:35357/v2.0 \
        create \
        --display-name "My First Volume!" \
        --display-description "Example Volume: OpenStack in Action" \
        1

sudo apt-get install -y qemu-utils
