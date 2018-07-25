#!/bin/bash
 
  prog="abcd_index.m3u8"
  bandwidthhd1080=2500000
  bandwidthhd720=1700000
  bandwidthhd504=1200000
  bandwidthhd360=800000
  bandwidthhd288=600000
  bandwidthhd144=300000
  bandwidthhd1080size=1920x1080
  bandwidthhd720size=1280x720
  bandwidthhd504size=896x504
  bandwidthhd360size=640x360
  bandwidthhd288size=512x288
  bandwidthhd144size=256x144
  hdmoviesource=(1080_main_stereo 720_main_stereo 504_main_stereo 360_main_stereo 288_main_stereo 144_main_stereo 504_baseline_stereo 360_baseline_stereo 288_baseline_stereo 144_baseline_stereo)
  hdmoviesourceweight=(1920 1280 896 640 512 256 896 640 512 256)
  hdmoviesourceheight=(1080 720 504 360 288 144 504 360 288 144)
  hdmoviesourcevrate=(2500 1700 1200 800 600 300 1200 800 600 300)
  hdmoviesourceprofile=(main main main main main main baseline baseline baseline baseline) 
  fondsizesource=(32 32 32 32 32 32 32 32 32 32)
  fondsizexpositionsource=(50 50 50 50 50 50 50 50 50 50)
 
  cd /home/reelboxencoding2/bin
   
  encoding(){
  local input=${1}
  local output=${2}     
  local profile=${3}
  local videoweight=${4}
  local videoheight=${5}
  local bitrate=${6}
  local fontsizeValue=${7}
  local fontsizexposition=${8}
 
  bitrateValue="$bitrate"k
  bufferValue="5097k"
 
  codec="-vcodec libx264 -profile:v $profile -level 4.1 -pix_fmt yuv420p -refs 5 -me_method umh -me_range 64 -nr 200 -r 24 -bf 5 -g 24 -x264opts keyint=24:min-keyint=24:no-scenecut"
  bitratevalue="-b:v $bitrateValue -maxrate $bitrateValue -bufsize $bufferValue"
     
  ./ffmpeg -y -i $input -acodec aac -strict experimental -ac 2 -ar 48000 -ab 192k -vf "drawtext=fontsize=$fontsizeValue:fontcolor=White@0.2:fontfile='font.TTF':text='REELBOX':x=$fontsizexposition:y=(h)/2" $codec $bitratevalue -f mp4 $output
 
 
   #./ffmpeg -y -i $input -c:v libx264 -profile:v $profile -level 4.1 -aspect "$videoweight:$videoheight" -vf "scale=$videoweight:-1,pad=$videoweight:$videoheight:(ow-iw)/2:(oh-ih)/2" -vb "$bitrate"k -minrate "$bitrate"k -maxrate "$bitrate*1.6"k -bufsize "$bitrate*1.6"k -refs 5 -me_method umh -me_range 64 -nr 200 -r 24 -bf 5 -g 24 -x264opts "keyint=24:min-keyint=24:no-scenecut" -pass 1 -an -f mp4 /dev/null 
   #./ffmpeg -y -i $input -c:v libx264 -profile:v $profile -level 4.1 -aspect "$videoweight:$videoheight" -vf "scale=$videoweight:-1,pad=$videoweight:$videoheight:(ow-iw)/2:(oh-ih)/2" -vb "$bitrate"k -minrate "$bitrate"k -maxrate "$bitrate*1.6"k -bufsize "$bitrate*1.6"k -refs 5 -me_method umh -me_range 64 -nr 200 -r 24 -bf 5 -g 24 -x264opts "keyint=24:min-keyint=24:no-scenecut" -pass 2 -codec:a aac -strict experimental -ac 2 -ar 48000 -b:a 192k -f mp4 $output 
  }
 
  segmenter(){
  local inputfile=${1}      local outputdir=${2}
    ./ffmpeg -i  $inputfile -codec copy -c:s mov_text -map 0 -f segment -segment_list $outputdir/$prog -vbsf h264_mp4toannexb -segment_list_flags +live -segment_time 10 $outputdir/filesequence-%d.ts
  }
 
  encryption_aes_cbc_128(){    
    local inputdir=${1}     local outputdir=${2}        local key_as_hex=${3}   local movieIdvalue=${4}   local key_index=${5}
    recenfilename=""
    for inputfilepath in "$inputdir"/*
    do
      filebasename=$(basename $inputfilepath)
      filedirname=$(dirname $inputfilepath)
      for j in $(echo $filebasename | tr "-" "\n")
      do
        if [[ "$j" =~ "ts" ]]; then
          init_vector=`printf '%032x'`
          openssl aes-128-cbc -e -in $filedirname/$recenfilename-$j -out $outputdir/$recenfilename-$j -p -nosalt -iv $init_vector -K $key_as_hex    
        else
          recenfilename=$j       
        fi
      done
    done
    while read line
    do
      if [[ "$line" =~ ".ts" ]]; then
        cd $outputdir
        newprefix=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)
        rename 's/^filesequence/'$newprefix'/' $line
        cd /home/reelboxencoding2/bin
        echo $line | sed -e 's/filesequence/'$newprefix'/g' >> $outputdir/$prog
      else
        echo "$line" >> $outputdir/$prog 
      fi
 
      if [[ "$line" =~ "TARGETDURATION" ]]; then
        echo "#EXT-X-KEY:METHOD=AES-128,URI=\"https://reelbox.tv/index.php?route=ios/key&reelboxencrypturl&movie=$movieIdvalue&key_index=$key_index\",IV=0x00000000000000000000000000000000" >> $outputdir/$prog  
      fi
    done < $inputdir/$prog 
  }
 
   
  
  create_main_m3u8(){
    local outputfilename=${1}  local resolution=("${!2}")      local resolutionfilename=("${!3}")     local resolutionband=("${!4}")   
    echo "#EXTM3U" >> $outputfilename 
    tLen=${#resolution[@]}   # get length of an array
    for (( i=0; i<${tLen}; i++ ));  
    do
      echo "#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=${resolutionband[$i]},RESOLUTION=${resolution[$i]}" >> $outputfilename
      echo "${resolutionfilename[$i]}" >> $outputfilename
    done
  }  
 
  create_movie_duration(){
    local inputfile=${1}        local outputdir=${2}
    movieduration=$(./ffmpeg -i $inputfile 2>&1 | grep Duration | cut -d ' ' -f 4 | sed s/,// )
    echo $movieduration  >> $outputdir/movieduration
  }
 
 
  if [ -n $1 ]; then
    echo "You entered $1"
  else
    echo "Usage: batch.sh <directory to pick mp4 files from>"
    exit;
  fi
 
  for destination in $1*
  do
    echo $destination
    OUTPUTDIR="$destination/output"
    if [ -d $OUTPUTDIR ]; then            #check the output dir exist    
      rm -R $OUTPUTDIR 
      #rm -R $destination/*_u.key
      #rm -R $destination/*_d.key
    fi
    mkdir $OUTPUTDIR                      #create output dir
 
    m3u8dir="$OUTPUTDIR/m3u8"  
    mkdir $m3u8dir #create root M3U8dir
 
    #openssl rand 16 > "$m3u8dir/static.key"
 
 
    while read MovieId
    do
      echo "movieid  is :$MovieId"   
    
      create_movie_duration $destination/mp4.mp4 $m3u8dir
      hdmoviesourceLen=${#hdmoviesource[@]}   # get length of an array
      #for (( i=0; i<1; i++ ));  
      for (( i=0; i<${hdmoviesourceLen}; i++ ));  
       
      do
        encoding $destination/mp4.mp4 $OUTPUTDIR/${hdmoviesource[$i]}.mp4 ${hdmoviesourceprofile[$i]} ${hdmoviesourceweight[$i]} ${hdmoviesourceheight[$i]} ${hdmoviesourcevrate[$i]} ${fondsizesource[$i]} ${fondsizexpositionsource[$i]}  
        decryptdir="$m3u8dir/${hdmoviesource[$i]}_dec"
        mkdir $decryptdir
        segmenter $OUTPUTDIR/${hdmoviesource[$i]}.mp4 $decryptdir        
        suffixaes=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)
        suffixkey=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)
        encryptdir="$m3u8dir/${hdmoviesource[$i]}_enc_$suffixaes"
        randomkey=$(( $RANDOM % 3000 )); 
        randomPath="/home/reelboxencoding2/bin/Generated_keys/$randomkey.txt"
        printf $(cat "$randomPath") >> "$destination/${hdmoviesource[$i]}.key"
        mkdir $encryptdir
        echo -n "${hdmoviesource[$i]}$suffixkey" >> $destination/${hdmoviesource[$i]}_u.key  
        echo -n "${hdmoviesource[$i]}_enc_$suffixaes" >> $destination/${hdmoviesource[$i]}_d.key
        encryption_aes_cbc_128 $decryptdir $encryptdir $(cat "$destination/${hdmoviesource[$i]}.key" | hexdump -e '16/1 "%02x"') $MovieId $(cat "$destination/${hdmoviesource[$i]}_u.key")
     done
 
      RokuIpadstereo=($bandwidthhd1080size $bandwidthhd720size $bandwidthhd504size $bandwidthhd360size $bandwidthhd288size $bandwidthhd144size)
      RokuIpadstereofile=($(cat "$destination/1080_main_stereo_d.key")/$prog $(cat "$destination/720_main_stereo_d.key")/$prog $(cat "$destination/504_main_stereo_d.key")/$prog $(cat "$destination/360_main_stereo_d.key")/$prog $(cat "$destination/288_main_stereo_d.key")/$prog $(cat "$destination/144_main_stereo_d.key")/$prog)
      RokuIpadstereoband=($bandwidthhd1080 $bandwidthhd720  $bandwidthhd504 $bandwidthhd360 $bandwidthhd288 $bandwidthhd144)
      WebAndroidH=($bandwidthhd504size $bandwidthhd360size $bandwidthhd288size $bandwidthhd144size)
      WebAndroidHfile=($(cat "$destination/504_main_stereo_d.key")/$prog $(cat "$destination/360_main_stereo_d.key")/$prog $(cat "$destination/288_main_stereo_d.key")/$prog $(cat "$destination/144_main_stereo_d.key")/$prog)
      WebAndroidHband=($bandwidthhd504 $bandwidthhd360 $bandwidthhd288 $bandwidthhd144)
      AndroidL=($bandwidthhd504size $bandwidthhd360size $bandwidthhd288size $bandwidthhd144size)
      AndroidLfile=($(cat "$destination/504_baseline_stereo_d.key")/$prog $(cat "$destination/360_baseline_stereo_d.key")/$prog $(cat "$destination/288_baseline_stereo_d.key")/$prog $(cat "$destination/144_baseline_stereo_d.key")/$prog)
      AndroidLband=($bandwidthhd504 $bandwidthhd360 $bandwidthhd288 $bandwidthhd144)
      create_main_m3u8 $m3u8dir/MSD.m3u8 RokuIpadstereo[@] RokuIpadstereofile[@] RokuIpadstereoband[@]
      create_main_m3u8 $m3u8dir/RokuIpad.m3u8 RokuIpadstereo[@] RokuIpadstereofile[@] RokuIpadstereoband[@] 
      create_main_m3u8 $m3u8dir/Chrome.m3u8 RokuIpadstereo[@] RokuIpadstereofile[@] RokuIpadstereoband[@] 
      create_main_m3u8 $m3u8dir/WebAndroidH.m3u8 WebAndroidH[@] WebAndroidHfile[@] WebAndroidHband[@]
      create_main_m3u8 $m3u8dir/AndroidL.m3u8 AndroidL[@] AndroidLfile[@] AndroidLband[@]  
 
      thumbdir="$m3u8dir/thumb"
      mkdir $thumbdir
      segmentTime=10
      ./ffmpeg -i $OUTPUTDIR/${hdmoviesource[0]}.mp4 -f image2 -bt 20M -vf fps=1/$segmentTime $thumbdir/%4d.png
      mogrify -geometry 100x $thumbdir/*.png
      imagesValue=$(find ${thumbdir} -type f | wc -l)
      count=$(($imagesValue/5))
      rem=$(($imagesValue%5))
      if [ $rem > 0 ];
      then
        count=$(($count+1))
      fi
      chmod -R 777 $thumbdir
      width=$( identify $thumbdir/0001.png | cut -d\   -f3 | cut -dx -f1 )
      height=$( identify $thumbdir/0001.png | cut -d\   -f3 | cut -dx -f2 )
      montage $thumbdir/*.png -tile 5x$count -geometry "$width"x"$height"+0+0 $thumbdir/myvideo.png
      yaxis=0
      starti=0
      endi=$segmentTime
      echo "WEBVTT" >> $thumbdir/image.webvtt
      for (( i=1; i <= $imagesValue; i=i+5 ));
      do
        xaxis=0 
        for (( j=$i; j < $i+5 && j <= $imagesValue; j++ ));  
        do
          starttime=$starti
          ((sec=starttime%60, starttime/=60, min=starttime%60, hrs=starttime/60))
          starttimestamp=$(printf "%d:%02d:%02d" $hrs $min $sec)
          endtime=$endi
          ((sec=endtime%60, endtime/=60, min=endtime%60, hrs=endtime/60))
          endtimestamp=$(printf "%d:%02d:%02d" $hrs $min $sec)
          echo "" >> $thumbdir/image.webvtt
          echo "$starttimestamp --> $endtimestamp" >> $thumbdir/image.webvtt
          echo "myvideo.png#xywh=$xaxis,$yaxis,$width,$height" >> $thumbdir/image.webvtt
          xaxis=$(($xaxis+$width))
          starti=$(($starti+$segmentTime))
          endi=$(($endi+$segmentTime))
        done
        yaxis=$(($yaxis+$height))
      done  
      keybackupdir="$m3u8dir/keybackup"
      mkdir $keybackupdir
      mv $destination/*.key $keybackupdir/
      cp $destination/movieid $m3u8dir/
       
      for (( i=0; i<${#hdmoviesource[@]}; i++ ));  
      do
        rm -R "$m3u8dir/${hdmoviesource[$i]}_dec"
      done    
    done < $destination/movieid    
  done
