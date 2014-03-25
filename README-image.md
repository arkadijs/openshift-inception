The CentOS demo image supplied by Eucalyptus install has too small root partition. To resolve that, install CentOS image from EuStore and resize it. 

Login as user you created while installing Cloud-in-a-Box, open terminal and find suitable image:

    eustore-describe-images
    eustore-install-image -i 3471904862 --hypervisor kvm -b centos64 -u admin

The `centos64` is bucket name. The user has auth credentials preconfigured (see `~/.euca/`) and `-u` tells the tool to use `eucalyptus/admin` account that has necessary permissions. `eustore-install-image` will properly register the _emi_ image and its _eki_ and _eri_ in Cloud Controller.

Next, download the root FS, unbundle it, resize, re-bundle, and re-upload:

    mkdir centos64
    euca-download-bundle -b centos64 -d centos64
    cd centos64
    mkdir image
    euca-unbundle -m euca-*.xml -d image -k ~/.euca/euca2-admin-*-pk.pem
    cd image
    e2fsck -fy *.img
    resize2fs *.img 10G
    tune2fs -O extents,uninit_bg,dir_index *.img
    e2fsck -fy *.img
    # add yourself to sudoers first
    # $ su -
    # $ usermod -a -G wheel <current user>
    # $ nano /etc/sudoers
    # uncomment %wheel  ALL=(ALL)   NOPASSWD: ALL
    # $ exit
    sudo mount -o loop *.img /mnt
    sudo sed -i -e 's/ext3/ext4/' /mnt/etc/fstab
    sudo umount /mnt
    mkdir bundle
    euca-bundle-image -i *.img -d bundle -r x86_64
    cd bundle
    euca-upload-bundle -b centos64 -m *.xml

Finally, grant the _emi_ to public so that `demo/admin` could launch the instances:

    euca-modify-image-attribute -l -a all emi-42F235E1
    euca-modify-image-attribute -l -a all eri-015435B7
    euca-modify-image-attribute -l -a all eki-2C54378B

Try it as `demo/admin`:

    euca-run-instances -k <your ssh key name> -g default -t c1.xlarge emi-42F235E1

Put `emi-42F235E1` in `inception.sh`.
