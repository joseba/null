virt-install --name=arch \
--vcpus=2 \
--ram=4096 \
--cdrom=/tmp/archlinux-2021.07.01-x86_64.iso \
--disk size=5 \
--network network=default \
--os-variant=archlinux \
--virt-type kvm \
--graphics none \
--serial pty \
--noautoconsole \
--console pty,target_type=serial 
#--graphics vnc,listen=0.0.0.0 --noautoconsole \
