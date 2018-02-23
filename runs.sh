#!/bin/bash
#
# BLOOD build script
#
# Copyright (C) 2016-2017 @AlexLartsev19
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

function step1_setup {
  echo "Setting building environment..."
  # Host
  export KBUILD_BUILD_USER=$(whoami)
  export KBUILD_BUILD_HOST=$(uname -n)
  export THREADS=$(nproc --all)
  # Dirs
  export KERNELDIR=$(pwd)
  export BUILDDIR=$KERNELDIR/build
  export CACHEDIR=$KERNELDIR/cache
  export OUTDIR=$KERNELDIR/out
  export SOURCESDIR=$BUILDDIR/obj
  export ZIPDIR=$BUILDDIR/zip
  # Kernel
  export ARCH=arm64
  export SUBARCH=arm64
  export CONFIG=m2note_defconfig
  export MODEL=m2note
  export DATE=$(date +"%Y%m%d%H%M")
  export BRANCH=$(git symbolic-ref --short HEAD)
  export VERSION=1.2
  export LOCALVERSION=$VERSION-Redsun
  export CROSS_COMPILE=/root/gcc-linaro-6.4.1/bin/aarch64-linux-gnu-
  STRIP=${CROSS_COMPILE}strip
  # Zip
  export ZIPTOOLS=$KERNELDIR/tools/zip
  export UNSIGNEDZIP=$LOCALVERSION-$MODEL-$DATE.zip
  export SIGNEDZIP=$LOCALVERSION-$MODEL-$DATE-signed.zip
  # Changelog
  export PREVIOUSTAG=$(git tag -l --sort=-taggerdate | grep -m 1 BLOOD)
  export PREVIOUSHASH=$(git log --format=%H -1 $PREVIOUSTAG)
  export CHANGELOG=$OUTDIR/$LOCALVERSION-$MODEL-$DATE-changelog.txt
}

function step2_preparation {
  begin=$(date +"%s")
  echo " "
  echo " "
  echo " "
  echo " "
  echo "======================================================================"
  echo " "
  echo " "
  echo " "
  echo " "
  echo "                          Kernel parameters:                          "
  echo " "
  echo " Architecture: $ARCH "
  echo " Defconfig: $CONFIG "
  echo " Version: $LOCALVERSION "
  echo " Toolchain: $CROSS_COMPILE "
  echo " Username: $KBUILD_BUILD_USER "
  echo " Hostname: $KBUILD_BUILD_HOST "
  echo " Host threads: $THREADS "
  echo " "
  echo " "
  echo " "
  echo " "
  echo "======================================================================"
  echo " "
  echo " "
  echo " "
  echo " "
  echo "Preparations for building..."
  mkdir -p $CACHEDIR
  if [ -f $OUTDIR/*.zip ]
  then
    mv $OUTDIR/*.zip $CACHEDIR/
  fi
  if [ -d $BUILDDIR ]
  then
    rm -rf $BUILDDIR
  fi
  if [ -d $OUTDIR ]
  then
    rm -rf $OUTDIR
  fi
  mkdir -p $BUILDDIR
  mkdir -p $OUTDIR
  mkdir -p $SOURCESDIR
  mkdir -p $ZIPDIR
}

function step3_building {
  echo " "
  echo "Building kernel..."
  make O=$SOURCESDIR $CONFIG
  make -j$THREADS O=$SOURCESDIR
  if [ -f $SOURCESDIR/arch/$ARCH/boot/Image.gz-dtb ]
  then
    cp -f $SOURCESDIR/arch/$ARCH/boot/Image.gz-dtb $ZIPDIR/zImage
    echo " "
    echo "Kernel succesfully built!"
    step4_zipit
    step5
    step6
  else
    echo " "
    echo "Building kernel failed!"
  fi
}

function step4_zipit {
  echo " "
  echo "Creating ZIP..."
  echo "# begin blood properties
ro.blood.version=$LOCALVERSION
ro.blood.model=$MODEL
ro.blood.build_date=$DATE
ro.blood.build_user=$KBUILD_BUILD_USER
ro.blood.build_host=$KBUILD_BUILD_HOST
# end blood properties" > $ZIPDIR/blood.prop
  cp -r $KERNELDIR/anykernel2/* $ZIPDIR/
  cd $ZIPDIR
  if [ -f $(find . -name placeholder) ]
  then
    rm -rf $(find . -name placeholder)
  fi
  zip -q -r -D -X $UNSIGNEDZIP ./*
  if [ -f $UNSIGNEDZIP ]
  then
    echo " "
    echo "Signing ZIP..."
    java -Xms2g -Djava.library.path=$ZIPTOOLS/signapk-resources/ -jar $ZIPTOOLS/signapk.jar -w $ZIPTOOLS/testkey.x509.pem $ZIPTOOLS/testkey.pk8 $UNSIGNEDZIP $SIGNEDZIP
    mv $SIGNEDZIP $OUTDIR/$SIGNEDZIP
  else
    echo " "
    echo "Couldn't find unsigned ZIP!"
  fi
}

function step5 {
  echo " "
  echo "Generating changelog from $PREVIOUSTAG tag..."
  git log --format="%nTitle: %s%nAuthor: %aN <%aE>%nAuthored on: %aD%nAdded on: %cD%n" $PREVIOUSHASH..HEAD > $CHANGELOG
  cd $KERNELDIR
  end=$(date +"%s")
}

function step6 {
  echo " "
  echo "Total time elapsed: $(echo $(($end-$begin)) | awk '{print int($1/60)"minutes "int($1%60)"seconds "}')"
  echo "Image location: $SOURCESDIR/arch/$ARCH/boot/Image.gz-dtb"
  echo "Image size: $(du -h $SOURCESDIR/arch/$ARCH/boot/Image.gz-dtb | awk '{print $1}')"
  echo "ZIP location: $OUTDIR/$SIGNEDZIP"
  echo "ZIP size: $(du -h $OUTDIR/$SIGNEDZIP | awk '{print $1}')"
}

step1_setup
step2_preparation
step3_building
