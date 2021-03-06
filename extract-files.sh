#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2018 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

DEVICE=jason
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$MY_DIR" ]]; then MY_DIR="$PWD"; fi

LINEAGE_ROOT="$MY_DIR"/../../..

HELPER="$LINEAGE_ROOT"/vendor/lineage/build/tools/extract_utils.sh
if [ ! -f "$HELPER" ]; then
    echo "Unable to find helper script at $HELPER"
    exit 1
fi
. "$HELPER"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

while [ "$1" != "" ]; do
    case $1 in
        -n | --no-cleanup )     CLEAN_VENDOR=false
                                ;;
        -s | --section )        shift
                                SECTION=$1
                                CLEAN_VENDOR=false
                                ;;
        * )                     SRC=$1
                                ;;
    esac
    shift
done

if [ -z "$SRC" ]; then
    SRC=adb
fi

# Initialize the helper
setup_vendor "$DEVICE" "$VENDOR" "$LINEAGE_ROOT" false "$CLEAN_VENDOR"

extract "$MY_DIR"/proprietary-files.txt "$SRC" "$SECTION"

DEVICE_BLOB_ROOT="$LINEAGE_ROOT"/vendor/"$VENDOR"/"$DEVICE"/proprietary

#
# Load camera configs from vendor
#
CAMERA2_SENSOR_MODULES="$DEVICE_BLOB_ROOT"/vendor/lib/libmmcamera2_sensor_modules.so
sed -i "s|/system/etc/camera/|/vendor/etc/camera/|g" "$CAMERA2_SENSOR_MODULES"

#
# Remove unused libcamera_client.so dependency in libsac.so
#
SAC="$DEVICE_BLOB_ROOT"/vendor/lib/libsac.so
patchelf --remove-needed libcamera_client.so "$SAC"

#
# Remove unused libmedia.so dependency in the IMS stack
#
DPLMEDIA="$DEVICE_BLOB_ROOT"/vendor/lib64/lib-dplmedia.so
patchelf --remove-needed libmedia.so "$DPLMEDIA"

#
# Replace libicuuc.so with libicuuc-v27.so for libMiCameraHal.so
#
MI_CAMERA_HAL="$DEVICE_BLOB_ROOT"/vendor/lib/libMiCameraHal.so
ICUUC_V27="$DEVICE_BLOB_ROOT"/vendor/lib/libicuuc-v27.so
patchelf --replace-needed libicuuc.so libicuuc-v27.so "$MI_CAMERA_HAL"
patchelf --set-soname libicuuc-v27.so "$ICUUC_V27"

#
# Replace libminikin.so with libminikin-v27.so for camera.sdm660.so
#
CAMERA_SDM660="$DEVICE_BLOB_ROOT"/vendor/lib/hw/camera.sdm660.so
MINIKIN_V27="$DEVICE_BLOB_ROOT"/vendor/lib/libminikin-v27.so
patchelf --replace-needed libminikin.so libminikin-v27.so "$CAMERA_SDM660"
patchelf --set-soname libminikin-v27.so "$MINIKIN_V27"

#
# Replace android.frameworks.sensorservice@1.0.so with android.frameworks.sensorservice@1.0-v27.so for libvideorefiner.so
#
patchelf --replace-needed android.frameworks.sensorservice@1.0.so android.frameworks.sensorservice@1.0-v27.so $DEVICE_BLOB_ROOT/vendor/lib/libvideorefiner.so

#
# Correct android.hidl.manager@1.0-java jar name
#
QTI_LIBPERMISSIONS="$DEVICE_BLOB_ROOT"/etc/permissions/qti_libpermissions.xml
sed -i "s|name=\"android.hidl.manager-V1.0-java|name=\"android.hidl.manager@1.0-java|g" "$QTI_LIBPERMISSIONS"

"$MY_DIR"/setup-makefiles.sh
