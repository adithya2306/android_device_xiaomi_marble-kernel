#!/bin/bash
#
# Copyright (C) 2023 Paranoid Android
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

### Setup
DUMP="${1}"
MY_DIR="${BASH_SOURCE%/*}"
declare -a MODULE_FOLDERS=("vendor_ramdisk" "vendor_dlkm" "system_dlkm")

if [ ! -f "${MY_DIR}/Module.symvers" ]; then
    touch "${MY_DIR}/Module.symvers"
fi
if [ ! -f "${MY_DIR}/System.map" ]; then
    touch "${MY_DIR}/System.map"
fi

# Check if dump is specified and exists
if [ "$#" -ne 1 ]; then
    echo "Please specify your dump"
    exit 1
fi
if [ ! -d "${DUMP}" ]; then
    echo "Unable to find dump at ${DUMP}"
    exit 1
fi

### Kernel
cp -f "${DUMP}/aosp-device-tree/prebuilts/kernel" "${MY_DIR}/Image"

### DTBS
# Cleanup / Preparation
if [ ! -d "${MY_DIR}/dtbs" ]; then
    mkdir "${MY_DIR}/dtbs"
fi

rm -f "${MY_DIR}/dtbs/00_kernel"
find "${MY_DIR}/dtbs" -type f -name "*.dtb" -delete
rm -f "${MY_DIR}/dtbs/dtbo.img"

# Copy
cp -f "${DUMP}/aosp-device-tree/prebuilts/dtbo.img" "${MY_DIR}/dtbs/dtbo.img"

mkdir "${MY_DIR}/_temp"
curl -L "https://raw.githubusercontent.com/PabloCastellano/extract-dtb/master/extract_dtb/extract_dtb.py" > ${MY_DIR}/_temp/extract_dtb.py
cp -f "${DUMP}/aosp-device-tree/prebuilts/dtb.img" "${MY_DIR}/_temp/dtb.img"
python3 "${MY_DIR}/_temp/extract_dtb.py" "${MY_DIR}/_temp/dtb.img" -o "${MY_DIR}/dtbs"
rm -rf "_temp"

### Modules
# Cleanup / Preparation
for MODULE_FOLDER in "${MODULE_FOLDERS[@]}"; do
    if [ -d "${MY_DIR}/${MODULE_FOLDER}" ]; then
        find "${MY_DIR}/${MODULE_FOLDER}" -type f -name "*.ko" -maxdepth 1 -delete
        find "${MY_DIR}/${MODULE_FOLDER}" -type f -name "*modules*" -maxdepth 1 -delete
    elif [ ! -d "${MY_DIR}/${MODULE_FOLDER}" ] && [ "${MODULE_FOLDER}" != "." ]; then
        mkdir "${MY_DIR}/${MODULE_FOLDER}"
    fi
done

# Copy
for MODULE_FOLDER in "${MODULE_FOLDERS[@]}"; do
    if [ "${MODULE_FOLDER}" == "vendor_ramdisk" ]; then
        mkdir "${MY_DIR}/_temp"
        curl -L "https://github.com/cfig/Android_boot_image_editor/releases/download/v13_r3/boot_editor_v13r3.zip" > ${MY_DIR}/_temp/boot_editor_v13r3.zip
        unzip "${MY_DIR}/_temp/boot_editor_v13r3.zip" -d "${MY_DIR}/_temp/"
        cp -f "${DUMP}/vendor_boot.img" "${MY_DIR}/_temp/boot_editor_v13r3/"
        ( cd "${MY_DIR}/_temp/boot_editor_v13r3/" && ./gradlew unpack )
        find "${MY_DIR}/_temp/boot_editor_v13r3/build/unzip_boot/root.1/" -type f -name "*.ko" -exec cp {} "${MY_DIR}/${MODULE_FOLDER}/" \;
        find "${MY_DIR}/_temp/boot_editor_v13r3/build/unzip_boot/root.1/" -type f -name "*modules*" -exec cp {} "${MY_DIR}/${MODULE_FOLDER}/" \;
        rm -rf "_temp"
    else
        find "${DUMP}/${MODULE_FOLDER}/" -type f -name "*.ko" -exec cp {} "${MY_DIR}/${MODULE_FOLDER}/" \;
        find "${DUMP}/${MODULE_FOLDER}/" -type f -name "*modules*" -exec cp {} "${MY_DIR}/${MODULE_FOLDER}/" \;
    fi
done
