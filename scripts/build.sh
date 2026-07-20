#!/usr/bin/env bash

set -e

CBOR_VERSION_STABLE="0.14.0" # https://github.com/PJK/libcbor/releases/tag/v0.14.0
IOS_VERSION_MIN="13.4"
MACOS_VERSION_MIN="11.0"
CODESIGN_ID="-"

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
echo "Script Path: ${SCRIPT_PATH}"

BUILD_ROOT_DIR="${SCRIPT_PATH}/../build"
echo "Build Path: ${BUILD_ROOT_DIR}"
mkdir -p "${BUILD_ROOT_DIR}"

if [[ -z $CBOR_VERSION ]]; then
  echo "CBOR_VERSION not set; falling back to ${CBOR_VERSION_STABLE} (Stable)"
  CBOR_VERSION="${CBOR_VERSION_STABLE}"
fi

CBOR_VERSION_FULL="${CBOR_VERSION}"
CBOR_VERSION_DOWNLOAD="${CBOR_VERSION_FULL%%-*}"

if [[ ! -f "${BUILD_ROOT_DIR}/v${CBOR_VERSION_DOWNLOAD}.tar.gz" ]]; then
  echo "Checking official GitHub release v${CBOR_VERSION_DOWNLOAD}"
  curl -fL "https://api.github.com/repos/PJK/libcbor/releases/tags/v${CBOR_VERSION_DOWNLOAD}" -o "${BUILD_ROOT_DIR}/v${CBOR_VERSION_DOWNLOAD}.release.json"

  echo "Downloading v${CBOR_VERSION_DOWNLOAD}.tar.gz"
  curl -fL "https://github.com/PJK/libcbor/archive/refs/tags/v${CBOR_VERSION_DOWNLOAD}.tar.gz" -o "${BUILD_ROOT_DIR}/v${CBOR_VERSION_DOWNLOAD}.tar.gz"
fi

SRC_DIR="${BUILD_ROOT_DIR}/cbor-src-${CBOR_VERSION_DOWNLOAD}"
BUILD_DIR="${BUILD_ROOT_DIR}/cbor-build-${CBOR_VERSION_FULL}"

if [[ ! -d "${SRC_DIR}" ]]; then
  mkdir -p "${SRC_DIR}"
  tar xzf "${BUILD_ROOT_DIR}/v${CBOR_VERSION_DOWNLOAD}.tar.gz" -C "${SRC_DIR}" --strip-components=1
fi

if [[ -d "${BUILD_DIR}" ]]; then
  rm -r "${BUILD_DIR}"
fi

mkdir -p "${BUILD_DIR}"

BUILD_DIR_MACOS="${BUILD_DIR}/macosx"
BUILD_DIR_IOS="${BUILD_DIR}/iphoneos"
BUILD_DIR_IOS_SIM="${BUILD_DIR}/iphonesimulator"

BUILD_DIR_MACOS_TEMP="${BUILD_DIR_MACOS}_temp"
BUILD_DIR_IOS_TEMP="${BUILD_DIR_IOS}_temp"
BUILD_DIR_IOS_SIM_TEMP="${BUILD_DIR_IOS_SIM}_temp"

THREAD_COUNT=$(sysctl hw.ncpu | awk '{print $2}')

copy_config() {
  local target_dir="$1"

  cp "${SCRIPT_PATH}/libcborConfig.cmake" "${target_dir}"

  cat > "${target_dir}/libcborConfigVersion.cmake" <<EOF
set(PACKAGE_VERSION "${CBOR_VERSION_DOWNLOAD}")

if(PACKAGE_VERSION VERSION_LESS PACKAGE_FIND_VERSION)
  set(PACKAGE_VERSION_COMPATIBLE FALSE)
else()
  set(PACKAGE_VERSION_COMPATIBLE TRUE)

  if(PACKAGE_VERSION VERSION_EQUAL PACKAGE_FIND_VERSION)
    set(PACKAGE_VERSION_EXACT TRUE)
  endif()
endif()
EOF

  cat >> "${target_dir}/libcborConfig.cmake" <<EOF

set(LIBCBOR_VERSION "${CBOR_VERSION_DOWNLOAD}")
EOF
}

build_macos() {
  echo "Building for macOS Universal"

  mkdir -p "${BUILD_DIR_MACOS_TEMP}"

  pushd "${BUILD_DIR_MACOS_TEMP}"

  local sdk_root=$(xcrun --sdk macosx --show-sdk-path)
  local additional_c_flags="-mmacosx-version-min=${MACOS_VERSION_MIN}"

  cmake "${SRC_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=Off \
    -DWITH_TESTS=Off \
    -DWITH_EXAMPLES=Off \
    -DSANITIZE=Off \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=Off \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE=Off \
    -DCMAKE_INSTALL_PREFIX="${BUILD_DIR_MACOS}" \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_SYSROOT="${sdk_root}" \
    -DCMAKE_SYSTEM_NAME="Darwin" \
    -DCMAKE_C_FLAGS="${additional_c_flags}" \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY

  cmake --build . --config Release --parallel "${THREAD_COUNT}"
  cmake --install . --config Release

  copy_config "${BUILD_DIR_MACOS}"

  popd
}

build_ios() {
  echo "Building for iOS ARM64"

  mkdir -p "${BUILD_DIR_IOS_TEMP}"

  pushd "${BUILD_DIR_IOS_TEMP}"

  local sdk_root=$(xcrun --sdk iphoneos --show-sdk-path)
  local additional_c_flags="-mios-version-min=${IOS_VERSION_MIN}"

  cmake "${SRC_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=Off \
    -DWITH_TESTS=Off \
    -DWITH_EXAMPLES=Off \
    -DSANITIZE=Off \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=Off \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE=Off \
    -DCMAKE_INSTALL_PREFIX="${BUILD_DIR_IOS}" \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_SYSROOT="${sdk_root}" \
    -DCMAKE_SYSTEM_NAME="iOS" \
    -DCMAKE_C_FLAGS="${additional_c_flags}" \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY

  cmake --build . --config Release --parallel "${THREAD_COUNT}"
  cmake --install . --config Release

  copy_config "${BUILD_DIR_IOS}"

  popd
}

build_ios_sim() {
  echo "Building for iOS Simulator"

  mkdir -p "${BUILD_DIR_IOS_SIM_TEMP}"

  pushd "${BUILD_DIR_IOS_SIM_TEMP}"

  local sdk_root=$(xcrun --sdk iphonesimulator --show-sdk-path)
  local additional_c_flags="-mios-simulator-version-min=${IOS_VERSION_MIN}"

  cmake "${SRC_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=Off \
    -DWITH_TESTS=Off \
    -DWITH_EXAMPLES=Off \
    -DSANITIZE=Off \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=Off \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE=Off \
    -DCMAKE_INSTALL_PREFIX="${BUILD_DIR_IOS_SIM}" \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_SYSROOT="${sdk_root}" \
    -DCMAKE_SYSTEM_NAME="iOS" \
    -DCMAKE_C_FLAGS="${additional_c_flags}" \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY

  cmake --build . --config Release --parallel "${THREAD_COUNT}"
  cmake --install . --config Release

  copy_config "${BUILD_DIR_IOS_SIM}"

  popd
}

build_macos
build_ios
build_ios_sim

if [[ ! -d "${BUILD_DIR}/CBOR.xcframework" ]]; then
  xcodebuild -create-xcframework \
    -library "${BUILD_DIR_MACOS}/lib/libcbor.a" \
    -library "${BUILD_DIR_IOS}/lib/libcbor.a" \
    -library "${BUILD_DIR_IOS_SIM}/lib/libcbor.a" \
    -output "${BUILD_DIR}/CBOR.xcframework"

  codesign \
    --force --deep --strict \
    --sign "${CODESIGN_ID}" \
    "${BUILD_DIR}/CBOR.xcframework"
fi
