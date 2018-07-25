#!/bin/bash
  encodingType=1
  prog="abcd_index.m3u8"
  bandwidthhd1080=2500000
  bandwidthhd720=1700000
  bandwidthhd504=1200000
  bandwidthhd360=800000
  bandwidthhd288=600000
  bandwidthhd1080size=1920x1080
  bandwidthhd720size=1280x720
  bandwidthhd504size=896x504
  bandwidthhd360size=640x360
  bandwidthhd288size=512x288
  hdmoviesource=(1080_main_stereo 720_main_stereo 504_main_stereo 360_main_stereo 288_main_stereo 504_baseline_stereo 360_baseline_stereo 288_baseline_stereo)
  hdmoviesourceweight=(1920 1280 896 640 512 896 640 512)
  hdmoviesourceheight=(1080 720 504 360 288 504 360 288)
  hdmoviesourcevrate=(2500 1700 1200 800 600 1200 800 600)
  hdmoviesourceprofile=(main main main main main baseline baseline baseline)
 
  cd /root/bin
 
  encoding(){
  #Encoding Setting
  local input=${1}
  local output=${2}     
  local profile=${3}
  local videoweight=${4}
  local videoheight=${5}
  local bitrate=${6}
 
  ./ffmpeg -y -i $input -c:v libx264 -profile:v $profile -level 4.1 -aspect "$videoweight:$videoheight" -vf "scale=$videoweight:-1,pad=$videoweight:$videoheight:(ow-iw)/2:(oh-ih)/2" -vb "$bitrate"k -minrate "$bitrate"k -maxrate "$bitrate*1.6"k -bufsize "$bitrate*1.6"k -refs 5 -me_method umh -me_range 64 -nr 200 -r 24 -bf 5 -g 24 -x264opts "keyint=24:min-keyint=24:no-scenecut" -pass 1 -an -f mp4 /dev/null
    
  ./ffmpeg -y -i $input -c:v libx264 -profile:v $profile -level 4.1 -aspect "$videoweight:$videoheight" -vf "scale=$videoweight:-1,pad=$videoweight:$videoheight:(ow-iw)/2:(oh-ih)/2" -vb "$bitrate"k -minrate "$bitrate"k -maxrate "$bitrate*1.6"k -bufsize "$bitrate*1.6"k -refs 5 -me_method umh -me_range 64 -nr 200 -r 24 -bf 5 -g 24 -x264opts "keyint=24:min-keyint=24:no-scenecut" -pass 2 -codec:a aac -strict experimental -ac 2 -ar 48000 -b:a 192k -f mp4 $output 
  }
 
  segmenter(){
  local inputfile=${1}      local outputdir=${2}
    ./ffmpeg -i  $inputfile -codec copy -c:s mov_text -map 0 -f segment -segment_list $outputdir/$prog -vbsf h264_mp4toannexb -segment_list_flags +live -segment_time 10 $outputdir/filesequence-%d.ts
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
    fi
    mkdir $OUTPUTDIR                      #create output dir
 
    m3u8dir="$OUTPUTDIR/m3u8"  
    mkdir $m3u8dir #create root M3U8dir
 
    
    create_movie_duration $destination/mp4.mp4 $m3u8dir
    hdmoviesourceLen=${#hdmoviesource[@]}   # get length of an array
    for (( i=0; i<${hdmoviesourceLen}; i++ ));  
    do
      encoding $destination/mp4.mp4 $OUTPUTDIR/${hdmoviesource[$i]}.mp4 ${hdmoviesourceprofile[$i]} ${hdmoviesourceweight[$i]} ${hdmoviesourceheight[$i]} ${hdmoviesourcevrate[$i]}             
      decryptdir="$m3u8dir/${hdmoviesource[$i]}_dec"
      mkdir $decryptdir
      segmenter $OUTPUTDIR/${hdmoviesource[$i]}.mp4 $decryptdir
    done
    highmain=($bandwidthhd1080size $bandwidthhd720size $bandwidthhd504size $bandwidthhd360size $bandwidthhd288size)
    highmainfile=(1080_main_stereo_dec/$prog 720_main_stereo_dec/$prog 504_main_stereo_dec/$prog 360_main_stereo_dec/$prog 288_main_stereo_dec/$prog)
    highmainband=($bandwidthhd1080 $bandwidthhd720 $bandwidthhd504 $bandwidthhd360 $bandwidthhd288)
 
    lowmain=($bandwidthhd504size $bandwidthhd360size $bandwidthhd288size)
    lowmainfile=(504_baseline_stereo_dec/$prog 360_baseline_stereo_dec/$prog 288_baseline_stereo_dec/$prog)
    lowmainband=($bandwidthhd504 $bandwidthhd360 $bandwidthhd288)
 
    create_main_m3u8 $m3u8dir/high.m3u8 highmain[@] highmainfile[@] highmainband[@]
    create_main_m3u8 $m3u8dir/low.m3u8 lowmain[@] lowmainfile[@] lowmainband[@]
  done
