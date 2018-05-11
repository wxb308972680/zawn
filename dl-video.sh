#!/bin/bash

path='/dev/shm/nsd/'
path=`pwd`'/nsd/'
mkdir -p $path
index_html=$path'index.html'
index_list=$path'index.list'



# 浏览器的 Cookie
cookie='Cookie: isCenterCookie=no; .local.language=zh-CN; Hm_lvt_9712e8cf4f76a1de06d6580a95348b4f=1523949081,1524223836,1524471957,1524742593; cloudAuthorityCookie=0; versionListCookie=NSD_V05; defaultVersionCookie=NSD_V05; courseCookie=LINUX; stuClaIdCookie=548464; sessionid=c718e4ca87ea48c7afafa6bdad570ab9|nsd1712n_pm%40tedu.cn; JSESSIONID=EBD72A17DC68D43FE831427DED0EE7A8; isCenterCookie=yes'
cookie='Cookie: sessionid=bca1d9f990454525af82ac2ce7782d30|nsd1802n_pm%40tedu.cn; cloudAuthorityCookie=0; versionListCookie=NSDTN201801; defaultVersionCookie=NSDTN201801; courseCookie=LINUX; stuClaIdCookie=562574; JSESSIONID=9817CD0380AF4021DACDFBD34C39A838; .local.language=zh-CN; isCenterCookie=yes'
# 浏览器类型
user_agent='User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:52.0) Gecko/20100101 Firefox/52.0'
user_agent='User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36'

# 下载课程清单，生成index.html、index.list文件
dl_index(){
	echo '开始下载 index.html'
	curl 'http://tts.tmooc.cn/studentCenter/toMyttsPage' \
	-H 'Host: tts.tmooc.cn' \
	-H "$user_agent" \
	-H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
	-H 'Accept-Language: zh-CN,zh;q=0.8,en-US;q=0.5,en;q=0.3' \
	-H 'Connection: keep-alive' \
	-H 'Upgrade-Insecure-Requests: 1' \
	-H "$cookie" --compressed -o $index_html
	awk '/<\/p>/{print str;str="";x=0};{if(x==1){str=str$1}};/<p>/{if(NR>40){str=$1;x=1}};/headline-content/{print};/showVideo/{print}' $index_html | sed -r 's///g' | sed -r 's/<p>/name|/g' | sed -r 's/.*href="(.*)".*/url|\1/g' | sed -r 's/.*>(.*)<.*/class|\1/g' > $index_list
}
# 下载其他页面，ts，key，m3u8
dl_other(){
	filename=${1##*/}
	curl $1 \
	-H 'Referer: '$2 \
	-H 'Origin: http://tts.tmooc.cn' \
	-H 'Accept-Encoding: gzip, deflate' \
	-H 'Accept-Language: zh-CN,zh;q=0.8' \
	-H 'Accept: */*' \
	-H 'Connection: keep-alive' \
	-H "$user_agent" --compressed -o $3$filename
}
dl_o(){
	local path=$PWD
	cd $3
	curl $1 \
	-H 'Referer: '$2 \
	-H 'Origin: http://tts.tmooc.cn' \
	-H 'Accept-Encoding: gzip, deflate' \
	-H 'Accept-Language: zh-CN,zh;q=0.8' \
	-H 'Accept: */*' \
	-H 'Connection: keep-alive' \
	-H "$user_agent" --limit-rate 1024k --compressed -O
	cd $path
}

# 下载播放页面
dl_player(){
	local class name url lpath
	read -p 'num=' num
	num=${num:-1}
	for i in `cat $index_list`
	do
		echo $i | grep '^class'
		[ $? -eq 0 ] && class=$num'.'${i:6} && let num++ && continue
		echo $i | grep '^name'
		[ $? -eq 0 ] && name=${i:5} && continue
		echo $i | grep '^url'
		if [ $? -eq 0 ]; then
			url=${i:4}
			lpath=$path$class'/'$name'/'
			# 创建目录
			mkdir -p $lpath
			# 开始下载播放页面
    	curl $url \
    	-H 'Accept-Encoding: gzip, deflate' \
    	-H 'Accept-Language: zh-CN,zh;q=0.8' \
    	-H 'Upgrade-Insecure-Requests: 1' \
    	-H "$user_agent" \
    	-H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8' \
    	-H 'Referer: http://tts.tmooc.cn/studentCenter/toMyttsPage' \
    	-H 'Connection: keep-alive' \
    	-H 'Cache-Control: max-age=0' \
		-H "$cookie" \
    	--compressed \
    	-o $lpath'player.html'
			# 正则匹配播放页面
			sed -rn '/"changeVideo/p' $lpath'player.html' | sed -rn $'s/\'/"/gp' | sed -rn 's/.*Video\("(.*)",.*title="(.*)">.*/\1=\2/p' > $lpath'player.list'
			for pl in `cat $lpath'player.list'`
			do
				dir=`echo $pl | sed -r 's/.*=(.*)/\1/g'`
				file=`echo $pl | sed -r 's/(.*)\.m3u8=.*/\1/g'`
				apm=$lpath$dir'/'
				mkdir -p $apm
				# 下载播放清单 m3u8 文件
				fn='http://videotts.it211.com.cn/'$file'/'$file'.m3u8'
				dl_other $fn $url $apm
				# 下载key和ts文件
				key=`egrep -o 'http.*\.key' $apm$file'.m3u8'`
				dl_other $key $url $apm
				len=`egrep -o 'http.*\.ts' $apm$file'.m3u8' | tail -1 | sed -r 's/(.*-)(.*)(\.ts)/\1[0-\2]\3/g'`
				dl_o $len $url $apm
			done
		fi
		# 下载完一个页面，暂停10秒
		echo '下载完一个页面:'$class'-'$name
		sleep 60
	done

}



#################################
# 脚本入口
#################################
# 一般不开
# dl_index
echo '==============================================='
dl_player

echo '--------------------------------------------------------------------------------------------------------'
sleep 60000

