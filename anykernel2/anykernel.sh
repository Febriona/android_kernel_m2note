# BLOOD installation script
# Based on AnyKernel2 by osm0sis @ xda-developers
# Modified by AlexLartsev19 @ github.com

# Advanced Settings
if [ -e /dev/block/platform/mtk-msdc.0/by-name/boot ]; then
  block=/dev/block/platform/mtk-msdc.0/by-name/boot;
elif [ -e /dev/block/platform/mtk-msdc.0/11230000.MSDC0/by-name/boot ]; then
  block=/dev/block/platform/mtk-msdc.0/11230000.MSDC0/by-name/boot;
fi;

# Installation Functions
ramdisk=/tmp/anykernel/ramdisk;
bin=/tmp/anykernel/tools;
split_img=/tmp/anykernel/split_img;
patch=/tmp/anykernel/patch;

chmod -R 755 $bin;
mkdir -p $ramdisk $split_img;

OUTFD=/proc/self/fd/$1;

ui_print() {
  echo "ui_print $1" > "$OUTFD";
  echo "ui_print" > "$OUTFD";
}

contains() {
  test "${1#*$2}" != "$1" && return 0 || return 1;
}

dump_boot() {
  if [ ! -e "$(echo $block | cut -d\  -f1)" ]; then
    ui_print " ";
    ui_print "Invalid partition. Aborting...";
    exit 1;
  fi;
  dd if=$block of=/tmp/anykernel/boot.img;
  $bin/unpackbootimg -i /tmp/anykernel/boot.img -o $split_img;
  if [ $? != 0 ]; then
    ui_print " ";
    ui_print "Dumping/splitting image failed. Aborting...";
    echo 1 > /tmp/anykernel/exitcode;
    exit;
  fi;
  mv -f $ramdisk /tmp/anykernel/rdtmp;
  mkdir -p $ramdisk;
  cd $ramdisk;
  gunzip -c $split_img/boot.img-ramdisk.gz | cpio -i;
  if [ $? != 0 -o -z "$(ls $ramdisk)" ]; then
    ui_print " ";
    ui_print "Unpacking ramdisk failed. Aborting...";
    echo 1 > /tmp/anykernel/exitcode;
    exit;
  fi;
  cp -af /tmp/anykernel/rdtmp/* $ramdisk;
}

write_boot() {
  cd $split_img;
  cmdline=`cat *-cmdline`;
  board=`cat *-board`;
  base=`cat *-base`;
  pagesize=`cat *-pagesize`;
  kerneloff=`cat *-kerneloff`;
  ramdiskoff=`cat *-ramdiskoff`;
  tagsoff=`cat *-tagsoff`;
  if [ -f *-second ]; then
    second=`ls *-second`;
    second="--second $split_img/$second";
    secondoff=`cat *-secondoff`;
    secondoff="--second_offset $secondoff";
  fi;
  if [ -f /tmp/anykernel/zImage ]; then
    kernel=/tmp/anykernel/zImage;
  elif [ -f /tmp/anykernel/zImage-dtb ]; then
    kernel=/tmp/anykernel/zImage-dtb;
  else
    kernel=`ls *-zImage`;
    kernel=$split_img/$kernel;
  fi;
  if [ -f /tmp/anykernel/dtb ]; then
    dtb="--dt /tmp/anykernel/dtb";
  elif [ -f *-dtb ]; then
    dtb=`ls *-dtb`;
    dtb="--dt $split_img/$dtb";
  fi;
  if [ -f "$bin/mkbootfs" ]; then
    $bin/mkbootfs $ramdisk | gzip > /tmp/anykernel/ramdisk-new.cpio.gz;
  else
    cd $ramdisk;
    find . | cpio -H newc -o | gzip > /tmp/anykernel/ramdisk-new.cpio.gz;
  fi;
  if [ $? != 0 ]; then
    ui_print " ";
    ui_print "Repacking ramdisk failed. Aborting...";
    echo 1 > /tmp/anykernel/exitcode;
    exit;
  fi;
  $bin/mkbootimg --kernel $kernel --ramdisk /tmp/anykernel/ramdisk-new.cpio.gz $second --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff $secondoff --tags_offset $tagsoff $dtb --output /tmp/anykernel/boot-new.img;
  if [ $? != 0 ]; then
    ui_print " ";
    ui_print "Repacking image failed. Aborting...";
    echo 1 > /tmp/anykernel/exitcode;
    exit;
  elif [ `wc -c < /tmp/anykernel/boot-new.img` -gt `wc -c < /tmp/anykernel/boot.img` ]; then
    ui_print " ";
    ui_print "New image larger than boot partition. Aborting...";
    echo 1 > /tmp/anykernel/exitcode;
    exit;
  fi;
  dd if=/tmp/anykernel/boot-new.img of=$block;
}

backup_file() {
  test ! -f $1~ && cp $1 $1~;
}

replace_string() {
  if [ -z "$(grep "$2" $1)" ]; then
      sed -i "s;${3};${4};" $1;
  fi;
}

replace_section() {
  begin=`grep -n "$2" $1 | head -n1 | cut -d: -f1`;
  for end in `grep -n "$3" $1 | cut -d: -f1`; do
    if [ "$begin" -lt "$end" ]; then
      sed -i "/${2//\//\\/}/,/${3//\//\\/}/d" $1;
      sed -i "${begin}s;^;${4}\n;" $1;
      break;
    fi;
  done;
}

remove_section() {
  begin=`grep -n "$2" $1 | head -n1 | cut -d: -f1`;
  for end in `grep -n "$3" $1 | cut -d: -f1`; do
    if [ "$begin" -lt "$end" ]; then
      sed -i "/${2//\//\\/}/,/${3//\//\\/}/d" $1;
      break;
    fi;
  done;
}

insert_line() {
  if [ -z "$(grep "$2" $1)" ]; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n "$4" $1 | head -n1 | cut -d: -f1` + offset));
    sed -i "${line}s;^;${5}\n;" $1;
  fi;
}

replace_line() {
  if [ ! -z "$(grep "$2" $1)" ]; then
    line=`grep -n "$2" $1 | head -n1 | cut -d: -f1`;
    sed -i "${line}s;.*;${3};" $1;
  fi;
}

remove_line() {
  if [ ! -z "$(grep "$2" $1)" ]; then
    line=`grep -n "$2" $1 | head -n1 | cut -d: -f1`;
    sed -i "${line}d" $1;
  fi;
}

prepend_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    echo "$(cat $patch/$3 $1)" > $1;
  fi;
}

insert_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n "$4" $1 | head -n1 | cut -d: -f1` + offset));
    sed -i "${line}s;^;\n;" $1;
    sed -i "$((line - 1))r $patch/$5" $1;
  fi;
}

append_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    echo -ne "\n" >> $1;
    cat $patch/$3 >> $1;
    echo -ne "\n" >> $1;
  fi;
}

replace_file() {
  cp -pf $patch/$3 $1;
  chmod $2 $1;
}

patch_fstab() {
  entry=$(grep "$2" $1 | grep "$3");
  if [ -z "$(echo "$entry" | grep "$6")" ]; then
    case $4 in
      block) part=$(echo "$entry" | awk '{ print $1 }');;
      mount) part=$(echo "$entry" | awk '{ print $2 }');;
      fstype) part=$(echo "$entry" | awk '{ print $3 }');;
      options) part=$(echo "$entry" | awk '{ print $4 }');;
      flags) part=$(echo "$entry" | awk '{ print $5 }');;
    esac;
    newentry=$(echo "$entry" | sed "s;${part};${6};");
    sed -i "s;${entry};${newentry};" $1;
  fi;
}

patch_cmdline() {
  cmdfile=`ls $split_img/*-cmdline`;
  if [ -z "$(grep "$1" $cmdfile)" ]; then
    cmdtmp=`cat $cmdfile`;
    echo "$cmdtmp $1" > $cmdfile;
  else
    match=$(grep -o "$1.*$" $cmdfile | cut -d\  -f1);
    sed -i -e "s;${match};${2};" -e 's;  ; ;' -e 's;[ \t]*$;;' $cmdfile;
  fi;
}

patch_prop() {
  if [ -z "$(grep "^$2=" $1)" ]; then
    echo -ne "\n$2=$3\n" >> $1;
  else
    line=`grep -n "^$2=" $1 | head -n1 | cut -d: -f1`;
    sed -i "${line}s;.*;${2}=${3};" $1;
  fi;
}

# Installation Proccess
chmod 750 $ramdisk/init.blood.rc
chmod 775 $ramdisk/sbin
chmod 755 $ramdisk/sbin/busybox

dump_boot;

backup_file init.mt6735.rc
insert_line init.mt6735.rc "init.blood.rc" after "import /init.modem.rc" "import /init.blood.rc";

write_boot;
