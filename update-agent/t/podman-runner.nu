#!/usr/bin/env nu
# Allows running tests inside of podman.
# If nu shell is not there, install it: 'cargo install --locked nu'

use std log

## TODO how to cleanup the temp directory?
def populate-mock-efivars [d] {
    0x[06 00 00 00 00 00 00 00] | save $"($d)/BootChainFwCurrent-781e084c-a330-417c-b678-38e696380cb9" --raw
    0x[07 00 00 00 00 00 00 00] | save $"($d)/RootfsStatusSlotB-781e084c-a330-417c-b678-38e696380cb9" --raw
    0x[06 00 00 00 03 00 00 00] | save $"($d)/RootfsRetryCountMax-781e084c-a330-417c-b678-38e696380cb9" --raw
    0x[07 00 00 00 03 00 00 00] | save $"($d)/RootfsRetryCountB-781e084c-a330-417c-b678-38e696380cb9" --raw
}

## TODO how to cleanup the temp directory?
def populate-mock-usr-persistent [d] {
    cp -r mock-usr-persistent/* $d
}

# Create a squashfs partition with Linux fs. I would prefer to emulate orb-os
# more closely, but that is kinda hard, so for now lets use one partition. In
# this case 'cuda' partition as it is the biggest one.
def populate-mnt [d] {
    podman run fedora-bootc:latest tar --one-file-system -cf - . | mksquashfs - $"($d)/cuda_layer.img" -tar -noappend -comp zstd
    let cuda_layer_hash = cat $"($d)/cuda_layer.img" | hash sha256
    let cuda_layer_size = ls $"($d)/cuda_layer.img" | get size.0 | into int

    echo  {
    "version": "6.3.0-LL-prod",
    "manifest": {
    "magic": "some magic",
    "type": "normal",
    "components": [
      {
        "name": "cuda_layer",
        "version-assert": "none",
        "version": "none",
        "size": ($cuda_layer_size),
        "hash": $"($cuda_layer_hash)",
        "installation_phase": "normal"
      }
    ]
  },
  "manifest-sig": "TBD",
  "sources": {
    "cuda_layer": {
      "hash": $"($cuda_layer_hash)",
      "mime_type": "application/octet-stream",
      "name": "cuda_layer",
      "size": $cuda_layer_size,
      "url": "/mnt/cuda_layer.img"
    },
  },
  "system_components": {
    "cuda_layer": {
      "type": "gpt",
      "value": {
        "device": "emmc",
        "label": "CUDA_LAYER",
        "redundancy": "redundant"
      }
    },
  }
  } | save $"($d)/claim.json"

  mkdir $"($d)/updates"
  return $d
}

def populate-mock-mmcblk [mmcblk] {
# root@localhost:~# parted /dev/mmcblk0
# uGNU Parted 3.3
# Using /dev/mmcblk0
# Welcome to GNU Parted! Type 'help' to view a list of commands.
# (parted) unit B print
# Model: MMC DG4016 (sd/mmc)
# Disk /dev/mmcblk0: 15758000128B
# Sector size (logical/physical): 512B/512B
# Partition Table: gpt
# Disk Flags:

# Number  Start         End           Size         File system  Name                  Flags
#  1      20480B        67129343B     67108864B    fat16        APP_a                 msftdata
#  2      67129344B     134238207B    67108864B    fat16        APP_b                 msftdata
#  3      134238208B    186667007B    52428800B                 BASE_LAYER_a          msftdata
#  4      186667008B    710955007B    524288000B                LFT_LAYER_a           msftdata
#  5      710955008B    1497387007B   786432000B                PACKAGES_LAYER_a      msftdata
#  6      1497387008B   5255483391B   3758096384B               CUDA_LAYER_a          msftdata
#  7      5255483392B   5360340991B   104857600B                SYSTEM_LAYER_a        msftdata
#  8      5360340992B   5361389567B   1048576B                  SECURITY_LAYER_a      msftdata
#  9      5361389568B   7240437759B   1879048192B               AI_LAYER_a            msftdata
# 10      7240437760B   7307546623B   67108864B                 SOFTWARE_LAYER_a      msftdata
# 11      7307546624B   7308595199B   1048576B                  CACHE_LAYER_a         msftdata
# 12      7308595200B   7361023999B   52428800B                 BASE_LAYER_b          msftdata
# 13      7361024000B   7885311999B   524288000B                LFT_LAYER_b           msftdata
# 14      7885312000B   8671743999B   786432000B                PACKAGES_LAYER_b      msftdata
# 15      8671744000B   12429840383B  3758096384B               CUDA_LAYER_b          msftdata
# 16      12429840384B  12534697983B  104857600B                SYSTEM_LAYER_b        msftdata
# 17      12534697984B  12535746559B  1048576B                  SECURITY_LAYER_b      msftdata
# 18      12535746560B  14414794751B  1879048192B               AI_LAYER_b            msftdata
# 19      14414794752B  14481903615B  67108864B                 SOFTWARE_LAYER_b      msftdata
# 20      14481903616B  14482952191B  1048576B                  CACHE_LAYER_b         msftdata
# 21      15134097408B  15136718847B  2621440B                  secure-os_b           msftdata
# 22      15136718848B  15136784383B  65536B                    eks_b                 msftdata
# 23      15136784384B  15137832959B  1048576B                  adsp-fw_b             msftdata
# 24      15137832960B  15138881535B  1048576B                  rce-fw_b              msftdata
# 25      15138881536B  15139930111B  1048576B                  sce-fw_b              msftdata
# 26      15139930112B  15141502975B  1572864B                  bpmp-fw_b             msftdata
# 27      15141502976B  15142551551B  1048576B                  bpmp-fw-dtb_b         msftdata
# 28      15142551552B  15209660415B  67108864B    fat32        esp                   boot, esp
# 29      15301738496B  15301758975B  20480B                    spacer                msftdata
# 30      15301758976B  15367819263B  66060288B                 recovery              msftdata
# 31      15367819264B  15368343551B  524288B                   recovery-dtb          msftdata
# 32      15368343552B  15368605695B  262144B                   kernel-bootctrl       msftdata
# 33      15368605696B  15368867839B  262144B                   kernel-bootctrl_b     msftdata
# 34      15368867840B  15683440639B  314572800B                RECROOTFS             msftdata
# 35      15683440640B  15683441663B  1024B                     UID                   msftdata
# 36      15683441664B  15683442687B  1024B                     UID-PUB               msftdata
# 37      15683442688B  15684491263B  1048576B     ext2         PERSISTENT            msftdata
# 38      15684491264B  15694977023B  10485760B    ext4         PERSISTENT-JOURNALED  msftdata
# 39      15694977024B  15757983231B  63006208B                 UDA                   msftdata

    truncate --size 15758000128 $mmcblk
    parted --script $mmcblk mklabel gpt
    parted --script $mmcblk mkpart primary 20480B        67129343B
    parted --script $mmcblk name 1    APP_a
    parted --script $mmcblk mkpart primary 67129344B     134238207B
    parted --script $mmcblk name 2    APP_b
    parted --script $mmcblk mkpart primary 134238208B    186667007B
    parted --script $mmcblk name 3    BASE_LAYER_a
    parted --script $mmcblk mkpart primary 186667008B    710955007B
    parted --script $mmcblk name 4   LFT_LAYER_a
    parted --script $mmcblk mkpart primary 710955008B    1497387007B
    parted --script $mmcblk name 5   PACKAGES_LAYER_a
    parted --script $mmcblk mkpart primary 1497387008B   5255483391B
    parted --script $mmcblk name 6  CUDA_LAYER_a
    parted --script $mmcblk mkpart primary 5255483392B   5360340991B
    parted --script $mmcblk name 7   SYSTEM_LAYER_a
    parted --script $mmcblk mkpart primary 5360340992B   5361389567B
    parted --script $mmcblk name 8     SECURITY_LAYER_a
    parted --script $mmcblk mkpart primary 5361389568B   7240437759B
    parted --script $mmcblk name 9  AI_LAYER_a
    parted --script $mmcblk mkpart primary 7240437760B   7307546623B
    parted --script $mmcblk name 10    SOFTWARE_LAYER_a
    parted --script $mmcblk mkpart primary 7307546624B   7308595199B
    parted --script $mmcblk name 11     CACHE_LAYER_a
    parted --script $mmcblk mkpart primary 7308595200B   7361023999B
    parted --script $mmcblk name 12    BASE_LAYER_b
    parted --script $mmcblk mkpart primary 7361024000B   7885311999B
    parted --script $mmcblk name 13   LFT_LAYER_b
    parted --script $mmcblk mkpart primary 7885312000B   8671743999B
    parted --script $mmcblk name 14   PACKAGES_LAYER_b
    parted --script $mmcblk mkpart primary 8671744000B   12429840383B
    parted --script $mmcblk name 15  CUDA_LAYER_b
    parted --script $mmcblk mkpart primary 12429840384B  12534697983B
    parted --script $mmcblk name 16   SYSTEM_LAYER_b
    parted --script $mmcblk mkpart primary 12534697984B  12535746559B
    parted --script $mmcblk name 17     SECURITY_LAYER_b
    parted --script $mmcblk mkpart primary 12535746560B  14414794751B
    parted --script $mmcblk name 18  AI_LAYER_b
    parted --script $mmcblk mkpart primary 14414794752B  14481903615B
    parted --script $mmcblk name 19    SOFTWARE_LAYER_b
    parted --script $mmcblk mkpart primary 14481903616B  14482952191B
    parted --script $mmcblk name 20     CACHE_LAYER_b
    parted --script $mmcblk mkpart primary 15134097408B  15136718847B
    parted --script $mmcblk name 21     secure-os_b
    parted --script $mmcblk mkpart primary 15136718848B  15136784383B
    parted --script $mmcblk name 22       eks_b
    parted --script $mmcblk mkpart primary 15136784384B  15137832959B
    parted --script $mmcblk name 23     adsp-fw_b
    parted --script $mmcblk mkpart primary 15137832960B  15138881535B
    parted --script $mmcblk name 24     rce-fw_b
    parted --script $mmcblk mkpart primary 15138881536B  15139930111B
    parted --script $mmcblk name 25     sce-fw_b
    parted --script $mmcblk mkpart primary 15139930112B  15141502975B
    parted --script $mmcblk name 26     bpmp-fw_b
    parted --script $mmcblk mkpart primary 15141502976B  15142551551B
    parted --script $mmcblk name 27     bpmp-fw-dtb_b
    parted --script $mmcblk mkpart primary 15142551552B  15209660415B
    parted --script $mmcblk name 28    esp
    parted --script $mmcblk mkpart primary 15301738496B  15301758975B
    parted --script $mmcblk name 29       spacer
    parted --script $mmcblk mkpart primary 15301758976B  15367819263B
    parted --script $mmcblk name 30    recovery
    parted --script $mmcblk mkpart primary 15367819264B  15368343551B
    parted --script $mmcblk name 31      recovery-dtb
    parted --script $mmcblk mkpart primary 15368343552B  15368605695B
    parted --script $mmcblk name 32      kernel-bootctrl
    parted --script $mmcblk mkpart primary 15368605696B  15368867839B
    parted --script $mmcblk name 33      kernel-bootctrl_b
    parted --script $mmcblk mkpart primary 15368867840B  15683440639B
    parted --script $mmcblk name 34   RECROOTFS
    parted --script $mmcblk mkpart primary 15683440640B  15683441663B
    parted --script $mmcblk name 35        UID
    parted --script $mmcblk mkpart primary 15683441664B  15683442687B
    parted --script $mmcblk name 36        UID-PUB
    parted --script $mmcblk mkpart primary 15683442688B  15684491263B
    parted --script $mmcblk name 37     PERSISTENT
    parted --script $mmcblk mkpart primary 15684491264B  15694977023B
    parted --script $mmcblk name 38    PERSISTENT-JOURNALED
    parted --script $mmcblk mkpart primary 15694977024B  15757983231B
    parted --script $mmcblk name 39    UDA
}
# NOTE: only works if built with 'cargo build --features skip-manifest-signature-verification'

def cmp-xz-with-partition [ota_file, partition_img] {
    let res = (xzcat $ota_file | cmp $partition_img - | complete)

    if ( $res | get exit_code ) != 0 {
          log error "partition content does not match expected"
          log error ( $res | get stdout )
          log error ( $res | get stderr )
          return false
    }
    return true
}

def cmp-img-with-partition [ota_file, partition_img] {
    let sz = (ls $ota_file | get size.0 | into int)
    let res = (cmp --bytes=($sz) $ota_file $partition_img | complete)

    if ( $res | get exit_code ) != 0 {
          log error "partition content does not match expected"
          log error ( $res | get stdout )
          log error ( $res | get stderr )
          return false
    }
    return true
}

export def "main mock" [mock_path] {
    mkdir $mock_path
    mkdir $"($mock_path)/efivars"
    let mock_efivars = populate-mock-efivars $"($mock_path)/efivars"
    mkdir $"($mock_path)/usr_persistent"
    let mock_usr_persistent = populate-mock-usr-persistent $"($mock_path)/usr_persistent"
    let mmcblk0 = populate-mock-mmcblk $"($mock_path)/mmcblk0"
    mkdir $"($mock_path)/mnt"
    let mock_mnt = populate-mnt $"($mock_path)/mnt"
}

def "main run" [prog, mock_path] {
    let absolute_path = ($prog | path expand)

    (podman run
     --rm
     -v $"($absolute_path):/var/mnt/program:Z"
     -w /var/mnt
     --security-opt=unmask=/sys/firmware
     --security-opt=mask=/sys/firmware/acpi:/sys/firmware/dmi:/sys/firmware/memmap
     --mount=type=bind,src=($mock_path)/efivars,dst=/sys/firmware/efi/efivars/,rw,relabel=shared,unbindable
     --mount=type=bind,src=./orb_update_agent.conf,dst=/etc/orb_update_agent.conf,relabel=shared,ro
     --mount=type=bind,src=($mock_path)/usr_persistent,dst=/usr/persistent/,rw,relabel=shared
     --mount=type=bind,src=($mock_path)/mnt,dst=/var/mnt,ro,relabel=shared
     --mount=type=tmpfs,dst=/var/mnt/updates/,rw
     --mount=type=bind,src=($mock_path)/mmcblk0,dst=/dev/mmcblk0,rw,relabel=shared
     -e RUST_BACKTRACE
     -it fedora-bootc:latest
     /var/mnt/program --nodbus
    )
}

def "main check" [mock_path] {
    let $mmcblk0 = $"($mock_path)/mmcblk0"
    ["run"
    "download /dev/sda2  ./APP_b.after_ota.img"
    "download /dev/sda19 ./SOFTWARE_LAYER_b.after_ota.img"
    "download /dev/sda16 ./SYSTEM_LAYER_b.after_ota.img"
    "download /dev/sda20 ./CACHE_LAYER_b.after_ota.img"
    ] | str join "\n" | guestfish --rw -a $mmcblk0


    if not (cmp-xz-with-partition ./s3_bucket/app.xz APP_b.after_ota.img) {
        log error "APP_b Test failed"
    }

    if not (cmp-img-with-partition ./s3_bucket/software_layer.img SOFTWARE_LAYER_b.after_ota.img) {
        log error "SOFTWARE_LAYER_b Test failed"
    }

    if not (cmp-img-with-partition ./s3_bucket/system_layer.img SYSTEM_LAYER_b.after_ota.img) {
        log error "SYSTEM_LAYER_b Test failed"
    }

    if not (cmp-img-with-partition ./s3_bucket/cache_layer.img CACHE_LAYER_b.after_ota.img) {
        log error "CACHE_LAYER_b Test failed"
    }
    rm APP_b.after_ota.img
}

export def "main clean" [mock_path] {
    rm -rf $mock_path
}

# Integration testing of update agent
def main [] {
  echo "main"
}
