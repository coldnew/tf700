#!/sbin/sh

echo "[available_size.sh] Get device free space info..."
bb=/tmp/aroma/busybox

if grep -q 'selected.0=1' /tmp/aroma-data/rootfs.prop; then
    echo "This script should be skipped, because selected 'Skip rootfs creation'"
    exit 0
fi

if grep -q 'selected.0=2' /tmp/aroma-data/rootfs.prop; then
    echo "Selected internal storage"
    rootfsfile=/data/media/linux/rootfs.img

    echo "install.disk=virtual" > /tmp/install.prop
    echo "install.to=${rootfsfile}" >> /tmp/install.prop

    mounted=$(df | grep -F '/mmcblk0p8 ' | grep -F '/data' | head -n1)

    if [ "x${mounted}" = "x" ]; then
        [ -d /data ] || mkdir /data
        [ -e /dev/block/mmcblk0p8 ] && mount -t ext4 /dev/block/mmcblk0p8 /data
        [ -e /dev/mmcblk0p8 ] && mount -t ext4 /dev/mmcblk0p8 /data
        mounted=$(df | grep -F '/mmcblk0p8 ' | grep -F '/data' | head -n1)
    fi

    disk_free=$($bb expr $(echo "${mounted}" | awk '{print $4}') / 1024 / 1024)
    overall_space_available=$disk_free

    if grep -q 'item.1.1=1' /tmp/aroma-data/options.prop; then
        echo "We don't need count size of rootfs.img - it will not be replaced."
        echo "install.replace=false" >> /tmp/install.prop
        newname="${rootfsfile}"
        while [ -f "${newname}" ]; do
            newname="$(echo "${rootfsfile}" | cut -d'.' -f1)-old${count}.img"
            count=$(($count+1))
        done
        echo "install.moveto=${newname}" >> /tmp/install.prop
    else
        echo "Search present virtual disk ${rootfsfile} ..."
        echo "install.replace=true" >> /tmp/install.prop
        echo "install.moveto=" >> /tmp/install.prop
        if [ -f "${rootfsfile}" ]; then
            out_image_size=$($bb expr $($bb stat -c "%s" "${rootfsfile}") / 1024 / 1024 / 1024)
            echo "Found virtual disk, size: ${out_image_size}Gb"
            overall_space_available=$($bb expr $out_image_size + $disk_free)
            echo "Changed space available from ${disk_free} to ${overall_space_available}Gb"
        fi
    fi

    echo "install.available=${overall_space_available}" >> /tmp/install.prop
else
    diskcount=$(cut -d'=' -f2 /tmp/aroma-data/rootfs.prop)
    disk=$(head -n${diskcount} /tmp/available_disks.list | tail -n1)
    overall_space_available=$($bb expr $(grep -F "available.${disk}=" /tmp/available_disks.prop | cut -d'=' -f2) / 1024)
    echo "Selected external disk ${disk}"

    [ -e "/dev/block/${disk}" ] && diskdevice="/dev/block/${disk}"
    [ -e "/dev/${disk}" ] && diskdevice="/dev/${disk}"

    echo "install.disk=${disk}" > /tmp/install.prop
    echo "install.dev=${diskdevice}" >> /tmp/install.prop
    echo "install.to=${diskdevice}" >> /tmp/install.prop
    echo "install.moveto=" >> /tmp/install.prop
    echo "install.available=${overall_space_available}" >> /tmp/install.prop
    echo "install.moveto=" >> /tmp/install.prop
fi

# Get image size
echo "Please, select virtual disk size (3...${overall_space_available}Gb): "

exit ${overall_space_available}
