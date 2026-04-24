#!/usr/bin/env bash

set -e

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
echo "Script Path: ${SCRIPT_PATH}"

if [[ -z $CBOR_VERSION ]]; then
  echo "CBOR_VERSION not set; aborting"
  exit 1
fi

BUILD_DIR="${SCRIPT_PATH}/../build/cbor-build-${CBOR_VERSION}"
echo "Build Path: ${BUILD_DIR}"

if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "Build dir not found: ${BUILD_DIR}"
  exit 1
fi

pushd "${BUILD_DIR}"

echo "Creating ${BUILD_DIR}/cbor.tar.gz"
rm -f "cbor.tar.gz"
tar czf "cbor.tar.gz" iphoneos iphonesimulator macosx

echo "Creating ${BUILD_DIR}/CBOR.xcframework.tar.gz"
rm -f "CBOR.xcframework.tar.gz"
tar czf "CBOR.xcframework.tar.gz" CBOR.xcframework

popd
