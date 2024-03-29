#!/bin/bash

set -e

COMPAT_SYMLINK_GENERATION_MAX=2

udevadm_version=$(udevadm --version)

regenerate_persistent_symlinks() {
    udevadm control --reload

    # --settle is supported since v249
    [ "$udevadm_version" -ge 249 ] &&
	    settle="--settle"

    udevadm trigger $settle \
	    --subsystem-match=block \
	    --sysname-match="nvme*" \
	    --sysname-match="sd*" \
	    --sysname-match="vd*"

    if [ "$settle" != "--settle" ]; then
        udevadm settle --timeout=10 ||
            echo >&2 "udevadm settle failed, ignoring"
    fi
}

cleanup() {
    rm -f $a $b
    rm -f /run/udev/rules.d/61-persistent-storage-compat.rules
    regenerate_persistent_symlinks
}

if source /usr/lib/udev/compat-symlink-generation 2>/dev/null; then
    if test "$COMPAT_SYMLINK_GENERATION" -ge $COMPAT_SYMLINK_GENERATION_MAX; then
        echo "This system is using compat symlink generation '$COMPAT_SYMLINK_GENERATION'."
        echo "This generation doesn't have any legacy symlink at this moment, hence your system"
        echo "can't possibly rely on such symlinks, all is good."
        exit 0
    fi

    echo "This system is using comat symlink generation $COMPAT_SYMLINK_GENERATION."
else
    echo "Failed to retrieve the compat symlink generation number, assuming generation 1."
fi

[ $UID -eq 0 ] || {
    echo "You must be root, aborting."
    exit 1
}

trap cleanup EXIT

# Get the list of the compat symlinks installed on this system (if any)
a=$(mktemp --tmpdir compat-symlink-finder-a.XXX)
b=$(mktemp --tmpdir compat-symlink-finder-b.XXX)

# Get the list of the symlinks including the compat ones
find /dev/disk/ -type l | sort | uniq >$a

mkdir -p /run/udev/rules.d/
ln -s /dev/null /run/udev/rules.d/61-persistent-storage-compat.rules
regenerate_persistent_symlinks

# Get the list of the symlinks without the compat ones
find /dev/disk/ -type l | sort | uniq >$b

# Get the diff between the 2 lists
symlinks=($(grep -Fxvf $b $a || :))

if test ${#symlinks[*]} -lt 1; then
    echo "No compat symlink found on this system, all is good."
    exit 0
fi

echo "Found the following compat symlinks:"
for l in "${symlinks[@]}"; do
    echo " $l"
done

conf_files=(
	/proc/cmdline
	/etc/crypttab
	/etc/default/grub
	/etc/default/grub_installdevice
	/etc/fstab
	/etc/lvm.conf
	/etc/mdadm.conf
	/etc/smartd.conf
)

found=0
for f in ${conf_files[*]}; do
    [ -f $f ] || continue

    echo
    echo "Checking whether they're referenced in $f..."

    found0=$found
    for l in "${symlinks[@]}"; do
        # Deprecated symlink paths can start with a dash and contains spaces
        grep -q -e "/$(basename -- "$l")" $f && {
            echo "$f: compat symlink '$l' referenced."
            let found+=1
        }
    done

    if [ $found -eq $found0 ]; then
        echo "Nothing found in $f."
    fi
done
echo

if [ $found -gt 0 ]; then
    echo "Some references to the legacy persistent symlinks have been found. Please update the"
    echo "affected files (see above) and replace all of them."
else
    echo "It seems that your system doesn't rely on a legacy symlinks at least for booting."
    echo "Hence disabling the generation of legacy symlinks should be safe. To be safe, you"
    echo "can try to boot with the following boot option specified in the kernel command"
    echo "and verify that your system is still booting properly:"
    echo "udev.compat_symlink_generation=0"
fi
