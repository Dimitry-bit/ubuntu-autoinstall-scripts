<h1 align="center">
  🛠️ Autoinstall Scripts
  <br>
</h1>

## Prerequisites

- An Ubuntu Desktop ISO, version 23.04 or later.

- `7z` for unpacking the source ISO.

```bash
sudo apt install p7zip
```

- `xorriso` for building the modified ISO.

```bash
sudo apt install xorriso
```

## Patching an Ubuntu's ISO

### 1. Unpack files from the Ubuntu 24.04 ISO.

```bash
7z -y x ubuntu-24.04-desktop-amd64.iso -osource-files
```

In the `source-files` directory you will find `[BOOT]` directory. That directory holds the mbr (master boot record) and efi (UEFI) partition images from the ISO. Those will not be used, so feel free to delete them.

```bash
rm -rf ./source-files/[BOOT]/
```

### 2. Edit the ISO grub.cfg file.

Edit `source-files/boot/grub/grub.cfg` and add the following menu entry above the existing menu entries.

```.
menuentry "Install Ubuntu (Autoinstall)" {
    set gfxpayload=keep
    linux   /casper/vmlinuz quiet autoinstall ds=nocloud\;s=/cdrom/desktop
    initrd  /casper/initrd
}
```

> [!CAUTION]
> Make sure "Install Ubuntu (Autoinstall)" is the first (default) menu entry, otherwise you will have to manually select it when you boot up.

### 3. Add your custom autoinstall `user-data` files.

Create a directory for `user-data`, and `meta-data` files.

```bash
mkdir source-files/desktop
```

Create an empty `meta-data` file.

```bash
touch source-files/desktop/meta-data
```

Add your custom `user-data` file.

```bash
cat <<EOF >./source-files/desktop/user-data
#cloud-config
autoinstall:
  version: 1
  source:
    id: ubuntu-desktop-minimal
    search_drivers: false
  codecs:
    install: false
  drivers:
    install: false
  identity:
    hostname: osc
    password: '\$y\$j9T\$q1iMlQ3R9/UXyj1jsomk61\$ZUxHgkyCZXf6OPxGyvHSGb6.EJZKuFBMACR6YSSGx8.'
    realname: osc
    username: osc
  keyboard:
    layout: us
    toggle: null
    variant: ''
  locale: en_US.UTF-8
  timezone: Africa/Cairo
EOF
```

> [!TIP]
> Use `mkpasswd` to generate a password hash.

A full list of `cloud-config` options can be found [here](https://canonical-subiquity.readthedocs-hosted.com/en/latest/reference/autoinstall-reference.html#ai).

### 4. Generate a new Ubuntu autoinstall ISO.

The following command is helpful when trying to setup the arguments for building an ISO. It will give flags and data to closely reproduce the source base install ISO.

```bash
xorriso -indev ubuntu-24.04-desktop-amd64.iso -report_el_torito as_mkisofs
```

Editing the report from the above I was able to come up with the command below for creating the autoinstall ISOs.

```bash
xorriso -as mkisofs -r \
  -V 'Ubuntu 24.04 LTS amd64' \
  --modification-date='2024042411290900' \
  --grub2-mbr --interval:local_fs:0s-15s:zero_mbrpt,zero_gpt:'ubuntu-24.04-desktop-amd64.iso' \
  --protective-msdos-label \
  -partition_cyl_align off \
  -partition_offset 16 \
  --mbr-force-bootable \
  -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b --interval:local_fs:11931884d-11942023d::'ubuntu-24.04-desktop-amd64.iso' \
  -appended_part_as_gpt \
  -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
  -c '/boot.catalog' \
  -b '/boot/grub/i386-pc/eltorito.img' \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  --grub2-boot-info \
  -eltorito-alt-boot \
  -e '--interval:appended_partition_2_start_2982971s_size_10140d:all::' \
  -no-emul-boot \
  -boot-load-size 10140 \
  -output "./ubuntu-24.04-desktop-amd64-autoinstall.iso" \
  ./source-files/
```

## Unattended Installation for Windows VirtualBox (`install-win.bat`)

### 1. Validations Thresholds

Validation variables are used to ensure that the host system meets the necessary resource requirements before initiating the installation.

```batch
set /A RAM_THRESHOLD_MB=4096
set /A CPU_PHYSICAL_CORES_THRESHOLD=4
set /A FREE_SPACE_THRESHOLD_MB=40960
```

> [!WARNING]
> `FREE_SPACE_THRESHOLD_MB` variable only works on `C:` drive.

### 2. Virtual Machine Configuration

These variables control the specifications of the virtual machine that will be created.

```batch
set /A MACHINE_PHYSICAL_CORES=2
set /A MACHINE_RAM_MB=4096
set /A MACHINE_DISK_SIZE_MB=25000
set "MACHINE_NAME=Ubuntu 24-04 (OSC)"
```

### 3. Virtual Machine Source and Destination

These variables specify the paths for the virtual machine's storage location and the source ISO file.

`MACHINE_DEST`: Defines the destination directory for the virtual machine files.

`ISO_SRC`: Specifies the path to the ISO file used for the unattended installation.

```batch
set "MACHINE_DEST=%UserProfile%\VirtualBox VMs"
set "ISO_SRC=.\ubuntu-24.04-desktop-amd64-autoinstall.iso"
```
