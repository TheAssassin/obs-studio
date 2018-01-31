#! /bin/bash

set -x
set -e

# need to detect version identifier before cd-ing into build directory
export VERSION=$(git rev-parse --short HEAD)

# use RAM disk if possible
if [ -d /dev/shm ]; then
    TEMP_BASE=/dev/shm
else
    TEMP_BASE=/tmp
fi

BUILD_DIR=$(mktemp -d -p "$TEMP_BASE" Pext-AppImage-build-XXXXXX)

cleanup () {
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
}

trap cleanup EXIT

# store repo root as variable
REPO_ROOT=$(readlink -f $(dirname $(dirname "$0")))
OLD_CWD=$(readlink -f .)

pushd "$BUILD_DIR"/

cmake "$REPO_ROOT" -DCMAKE_INSTALL_PREFIX:PATH=/usr
make -j$(nproc)
mkdir AppDir
make DESTDIR=AppDir install

# inspect AppDir -- TODO: remove this line before release
tree AppDir

mkdir -p AppDir/usr/share/{applications,icons/hicolor/256x256}
cp "$REPO_ROOT"/UI/dist/obs.desktop AppDir/usr/share/applications/
cp "$REPO_ROOT"/UI/forms/images/obs.png AppDir/usr/share/icons/hicolor/256x256/

wget -nv "https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-x86_64.AppImage"

chmod +x linuxdeployqt-continuous-x86_64.AppImage
./linuxdeployqt-continuous-x86_64.AppImage --appimage-extract

# fix environment
unset QTDIR
unset QT_PLUGIN_PATH
unset LD_LIBRARY_PATH

# add Git commit ID to AppImage filename
squashfs-root/AppRun AppDir/usr/share/applications/obs.desktop -verbose=3 -bundle-non-qt-libs
squashfs-root/AppRun AppDir/usr/share/applications/obs.desktop -verbose=3

patchelf --set-rpath "\$ORIGIN" AppDir/usr/lib/libobs*.so*

rm AppDir/AppRun

cat > AppDir/AppRun <<EOF
#! /bin/sh

if [ -z \$APPDIR ]; then
    export APPDIR=\$(realpath \$(dirname \$(basename "\$0")))
fi

export OBS_DATA_PATH="\$APPDIR"/usr/share/obs/obs-studio/
export LD_LIBRARY_PATH="\$APPDIR"/usr/lib

"\$APPDIR"/usr/bin/obs
EOF

chmod +x AppDir/AppRun

# clean up linuxdeployqt
rm -rf squashfs-root/

# get appimagetool
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
./appimagetool-x86_64.AppImage --appimage-extract

# build AppImage
squashfs-root/AppRun AppDir/

# move AppImage back to old CWD
mv OBS-*.AppImage* "$OLD_CWD"/
