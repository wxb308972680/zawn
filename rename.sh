#!/bin/bash

#read -p '请输入保存目录:' path
path=${path:-/dev/shm/0}
fn=`ls *m.m3u8`
[ -z $fn ] && echo $PWD && exit 1
kfn=key_$fn
mv static.key $path/$kfn
mv *.m3u8 $path/
mv *.ts $path/
sed -ri '/http/s/http.*m\///g' $path/$fn
sed -ri "s/static\.key/$kfn/g" $path/$fn
ffmpeg -i $path/$fn -c copy /root/桌面/my/vdl/NSD1712/0${fn%\.m3u8}.mp4 2>> /dev/shm/err.log



