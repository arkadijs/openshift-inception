The CentOS demo image supplied by Eucalyptus install is no good for OpenShift: (a) it has too small root partition, (b) it use _ext3_ as root FS type. Let modify it.

First, login as user you created while installing Cloud-in-a-box, open terminal and setup _sudo_ rights:

    su -
    usermod -a -G wheel $USER
    yum install -y nano
    nano /etc/sudoers
    # uncomment towards the end of the file
    # %wheel  ALL=(ALL)   NOPASSWD: ALL
    exit

Next, download the image, unbundle it, resize, re-bundle, and re-upload:

    mkdir centos6
    euca-download-bundle -b centos6 -d centos6
    cd centos6
    mkdir image
    sudo cp /var/lib/eucalyptus/keys/cloud-pk.pem .
    sudo chown $USER cloud-pk.pem
    euca-unbundle -m ks-centos6-*.xml -d image -k cloud-pk.pem
    cd image
    e2fsck -fy *.img
    resize2fs *.img 9G
    tune2fs -O extents,uninit_bg,dir_index *.img
    e2fsck -fy *.img
    

The `-b centos6` above is a bucket name where kick-start image is installed.

Now, modify filesystem type and create new initramfs. (The kernel and initramfs from _eki_ / _eri_ are _kexec_ bootstrap that will load real kernel and initramfs from the _emi_.)

    sudo mount -o loop *.img /mnt
    sudo sed -i -e 's/ext3/ext4/' /mnt/etc/fstab
    v=2.6.32-431.5.1.el6.x86_64
    dracut --nomdadmconf --filesystems ext4 \
      --add-drivers "virtio_net virtio_pci virtio_blk virtio_balloon" \
      initramfs-$v.img $v
    mv /mnt/boot/initramfs-$v.img /mnt/boot/initramfs-$v.img~
    mv initramfs-$v.img /mnt/boot/
    sudo umount /mnt
    

Finish it with cloud key and upload to new bucket:

    mkdir bundle
    euca-bundle-image -i *.img -d bundle -r x86_64 \
      --kernel eki-74FF39D4 --ramdisk eri-C31B4030 \
      -k ../cloud-pk.pem
    euca-upload-bundle -b centos6-custom -m bundle/*.xml
    euca-register centos6-custom/ks-centos6-201403251837.img.manifest.xml \
      -n centos6-custom -a x86_64
    euca-modify-image-attribute -l -a all emi-42F235E1

Try it as `demo/admin` from your workstation:

    euca-run-instances -k <your ssh key name> -g default -t c1.xlarge emi-42F235E1

Put `emi-42F235E1` in `inception.sh`.

For details consult [Eucalyptus manual](https://www.eucalyptus.com/docs/eucalyptus/3.4/index.html#image-guide/img_add_existing.html).
