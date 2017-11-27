#! /bin/bash

set -x
set -e

mkdir appimage-build
cd appimage-build/

cmake .. -DCMAKE_INSTALL_PREFIX:PATH=/usr
make -j$(nproc)
mkdir AppDir
make DESTDIR=AppDir install

# inspect AppDir -- TODO: remove this line before release
tree AppDir

mkdir -p AppDir/usr/share/{applications,icons/hicolor/256x256}
cp ../UI/dist/obs.desktop AppDir/usr/share/applications/
cp ../UI/forms/images/obs.png AppDir/usr/share/icons/hicolor/256x256/

wget -nv "https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-x86_64.AppImage"

chmod +x linuxdeployqt-continuous-x86_64.AppImage

# fix environment
unset QTDIR
unset QT_PLUGIN_PATH
unset LD_LIBRARY_PATH

# add Git commit ID to AppImage filename
export VERSION=$(git rev-parse --short HEAD)
./linuxdeployqt-continuous-x86_64.AppImage AppDir/usr/share/applications/obs.desktop -bundle-non-qt-libs
./linuxdeployqt-continuous-x86_64.AppImage AppDir/usr/share/applications/obs.desktop -appimage
