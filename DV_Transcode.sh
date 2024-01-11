#!/bin/bash

# Function for transcoding. Argument position: 1: Original File location 2: Directory for transcoded movie 3: resolution width in pixel (e.g. 1920 or 3840) 4: resolution string (e.g. 1080p)
transcode(){
  #Prep Transcode
    #LOGS
    trans_log="${log_dir_movie_date}/${title}${teststring} - ${4}_transcode.log"
    touch "${trans_log}"
    echo "Title: ${title}" >> "${trans_log}"
    echo "Log for: ${current_date_time}" >> "${trans_log}"
    remux_log="${log_dir_movie_date}/${title}${teststring} - ${4}_remux.log"
    touch "${remux_log}"
    echo "Title: ${title}" >> "${remux_log}"
    echo "Log for: ${current_date_time}" >> "${remux_log}"
    dovi_demux_log="${log_dir_movie_date}/${title}${teststring} - ${4}_dovi_demux.log"
    touch "${dovi_demux_log}"
    echo "Title: ${title}" >> "${dovi_demux_log}"
    echo "Log for: ${current_date_time}" >> "${dovi_demux_log}"
    DV_remux_log="${log_dir_movie_date}/${title}${teststring} - ${4}_DV_remux.log"
    touch "${DV_remux_log}"
    echo "Title: ${title}" >> "${DV_remux_log}"
    echo "Log for: ${current_date_time}" >> "${DV_remux_log}"
    #Outputpath
    #Create folder for FHD run
    if [[ ${fhd_run} == "true" ]]; then
      mkdir "${working_dir_movie}/FHD"
      blayer_transcoded="${working_dir_movie}/FHD/BL_FHD_transcoded.hevc"
      dv_transcoded_hevc="${working_dir_movie}/FHD/DV_FHD_transcoded.hevc"
    else
      blayer_transcoded="${working_dir_movie}/BL_transcoded.hevc"
      dv_transcoded_hevc="${working_dir_movie}/DV_transcoded.hevc"
    fi

    blayer="${working_dir_movie}/BL.hevc"
    elayer="${working_dir_movie}/EL.hevc"
    trans_movie="${2}/${title}${teststring} - ${4}.${container}"
    trans_movie_DV="${target_dir_movie}/${title}${teststring} - DV${4}.${container}"

    if [[ -f ${trans_movie} ]] || ([[ ${onlyDVmovie} == "true" ]] && [[ -f ${trans_movie_DV} ]]); then
      tr_mov_existed="true"
    else
      tr_mov_existed="false"
    fi
  #Transcode
  if [[ $tr_mov_existed == "false" ]] || [[ ${overwrite} == "true" ]]; then
    echo -e "${ORANGE}Transcoding in ${4} starts now.${NOCOLOR}"
    #Note to self: DoviTool necessary with DV to fix NAL 63 skipping bug.
    if [[ ${doDV} == "true" ]]; then
      echo -e "${ORANGE}Dolby Vision detected.${NOCOLOR}"
      # Prepare log
      DV_dovi_demux_log="${log_dir_movie_date}/${title}_RPU_demux.log"
      touch "${DV_dovi_demux_log}"
      echo "Title: ${title}" >> "${DV_dovi_demux_log}"
      echo "Log for: ${current_date_time}" >> "${DV_dovi_demux_log}"
      DV_ffmpeg_demux_log="${log_dir_movie_date}/${title}_orig_demux.log"
      touch "${DV_ffmpeg_demux_log}"
      echo "Title: ${title}" >> "${DV_ffmpeg_demux_log}"
      echo "Log for: ${current_date_time}" >> "${DV_ffmpeg_demux_log}"
      if [[ ${fhd_run} == "true" ]]; then
        cd "${working_dir_movie}/FHD"
      else
        cd "${working_dir_movie}"
      fi
      if [[ ! -f "$blayer" ]] || [[ $overwrite == "true" ]]; then
      ffmpeg -t "${stop_at_t}" -i "${1}" -c:V copy -bsf:V hevc_mp4toannexb -f hevc - 2> "${DV_ffmpeg_demux_log}" | dovi_tool -m 2 demux - 2>&1 | tee -a "${dovi_demux_log}"
      fi
      ffmpeg -t "${stop_at_t}" -i "${blayer}" -c:V "${encoder}" -filter:V scale="${3}" -preset "${enc_speed}" -profile:V main10 -cq "${enc_q}"  -map 0 "${blayer_transcoded}"  2>&1 | tee -a "${trans_log}"
      if [[ ${onlyDVmovie} != "true" ]]; then
        ffmpeg -t "${stop_at_t}" -i "${blayer_transcoded}" -t "${stop_at_t}" -i "${1}" -map 0:V -c:V copy -map 1:a -c:a "${audio_codec}" -b:a "${a_bitrate}" -map 1:s -c:s copy "${trans_movie}" 2>&1 | tee -a "${remux_log}"
      fi
      dovi_tool mux --bl "${blayer_transcoded}" --el "${elayer}" -o "${dv_transcoded_hevc}"
      ffmpeg -t "${stop_at_t}" -i "${dv_transcoded_hevc}" -t "${stop_at_t}" -i "${1}" -map 0:V -c:V copy -map 1:a -c:a "${audio_codec}" -b:a "${a_bitrate}" -map 1:s -c:s copy "${trans_movie_DV}" 2>&1 | tee -a "${DV_remux_log}"
    else
      echo -e "${ORANGE}No Dolby Vision detected. Normal encode.${NOCOLOR}"
      ffmpeg -t "${stop_at_t}" -i "${1}" -c:a "${audio_codec}" -b:a "${a_bitrate}" -c:s copy -c:V "${encoder}" -preset "${enc_speed}" -profile:V main10 -cq "${enc_q}" -map 0 "${trans_movie}" 2>&1 | tee -a "${trans_log}"
      #HandBrakeCLI -i "${1}" --stop-at "${stop_at_f}" -o "${trans_movie}" -m -O -e nvenc_h265_10bit --encoder-preset "${enc_speed}" -q "${enc_q}" --width ${3} --subtitle-lang-list eng,deu --all-subtitles  --audio-lang-list eng,deu --all-audio -E copy --audio-copy-mask dtshd,ac3,eac3 --audio-fallback eac3 -6 7point1 -B 896 --loose-anamorphic --modulus 2 2>&1 | tee -a "${trans_log}"
    fi
  else
    echo -e "${ORANGE}Transcoded movie in resolution ${3} found, scipping.${NOCOLOR}" 2>> "${gen_log}"
  fi
}

ORANGE='\033[35;1m'
NOCOLOR='\033[0m'

echo -e "${ORANGE}You script is located in: $(dirname $0)"
if [[ ! -f "$(dirname $0)/DV_Transcode.conf" ]]; then
  echo -e "Could not find DV_Transcode.conf in  $(dirname $0) Please provide a path: "

  read confdir

else
  confdir="$(dirname $0)/DV_Transcode.conf"
fi

# Read configuration orig_file
source "${confdir}"

  if [ $test == "true" ]; then
    teststring=" - test"
  else
    teststring=
  fi

echo -e "All .mkv .MKV .m4v files in ${source_dir} will be transcoded."
echo -e "But the following filter will be applied: $filter"
echo -e "Override is: ${overwrite} - When true, every movie and/or temp file will be overwritten. If false, it will skip already existing files."
echo -e "All transcoded files will go to: ${target_dir}"
echo -e "The working directory for temp files is: ${working_dir}"
echo -e "The encoder is: ${encoder}"
echo -e "The speed of encoder is: ${enc_speed}"
echo -e "The quality of video encoder is: ${enc_q}"
echo -e "The audio codec is: ${audio_codec}"
echo -e "The bitrate of audio encoder is: ${a_bitrate}"
echo -e "The container type is: ${container}"
echo -e "Dolby Vision Conversion: ${dov}"
echo -e "Only original resolution mode: ${only_orig_res} - True will not create an FHD Version."
echo -e "Test Run Mode is ${test} - True only converts to minute 3 of a movie. Files will be marked with '_test'."
echo -e "Cleanup state is: ${cleanup} - True will delete all tmp files, such as video bitstream and RPU DV Metadata."
echo -e "Only DV Version is: ${onlyDVmovie} - True will only give you DV Version. False also provides non DV version."
echo -e "Log will be stored in: ${logdir}"
echo -e "Here is a List of all files you selected:${NOCOLOR}"

shopt -s nullglob
for orig_file in $source_dir/*.{mkv,MKV,m4v}; do
  # Check if orig_file has already been processed and filter according to user input
  if [[ ${orig_file} = *"${filter}"* ]] || ([[ -z "${teststring}" ]] && [[ ${orig_file} = *"${filter}"* ]] && [[ ${orig_file} = *"_test"* ]]); then
    echo $orig_file
  fi
done

echo -e "${ORANGE}If you are not happy with this config, change the config file: ${confdir}"

echo -e "Do you want to continue? (yes/no)${NOCOLOR}"
read user_input


if [ $user_input == "yes" -o $user_input == "y" ]; then
    echo -e "Continuing..."
else
    if [ $user_input == "no" -o $user_input == "n" ] ; then
        echo -e "Exiting..."
        exit
    else
        echo -e "Invalid Input, Exiting..."
        exit
    fi
fi

shopt -s nullglob
for orig_file in $source_dir/*.{mkv,MKV,m4v}; do
  # Check if orig_file has already been processed and filter according to user input
  if [[ ${orig_file} = *"${filter}"* ]] || ([[ -z "${teststring}" ]] && [[ ${orig_file} = *"${filter}"* ]] && [[ ${orig_file} = *"_test"* ]]); then
    echo $orig_file

    # Set current Date/time
    current_date_time=$(date +"%Y%m%d_%H%M%S")


    #(Re)set Variables
    trans_log=
    trans_movie=
    trans_movie_DV=
    fhd_run="false"

    # Get movie title from orig_file name
    title=$(basename "${orig_file}")
    title="${title%.*}"


    # Create subdirectories for movie
    mkdir "${working_dir}" -v
    working_dir_movie="${working_dir}/${title}"
    mkdir "${working_dir_movie}" -v

    mkdir "${target_dir}" -v
    target_dir_movie="${target_dir}/${title}"
    mkdir "${target_dir_movie}" -v

    mkdir "${log_dir}" -v
    log_dir_movie="${log_dir}/${title}"
    mkdir "${log_dir_movie}" -v

    # Prepare general logfile

    log_dir_movie_date="${log_dir_movie}/${current_date_time}"
    mkdir "${log_dir_movie_date}" -v
    gen_log="${log_dir_movie_date}/${title}.log"
    touch "${gen_log}"
    echo "Title: ${title}" >> "${gen_log}"
    echo "Log for: ${current_date_time}" >> "${gen_log}"
    cat $confdir >> "${gen_log}"


    echo -e "${ORANGE}Doing file ${orig_file}${NOCOLOR}"  2>> "${gen_log}"s

    # Get movie length. Necessary because test mode requires a specified stop at for HandBrakeCLi and ffmpeg. Cannot be NULL.
    movie_len=$(mediainfo --Output=General\;%Duration% "${orig_file}")
    movie_len_s=$((${movie_len}/1000+1))

    # Set stop at according to config
    if [ $test == "true" ]; then
      stop_at_t="60"
    else
      stop_at_t=$movie_len_s
    fi

    # Get resolution of orig_file using mediainfo
    resolution=$(mediainfo --Output=Video\;%Width%x%Height% "${orig_file}")
    res_width=$(cut -d x -f 1 <<< $resolution)
    res_height=$(cut -d x -f 2 <<< $resolution)
    orig_scale="${res_width}x${res_height}"
    fhd_width=1920
    fhd_scale="${fhd_width}:-1"


    echo -e "${ORANGE}Title of movie is: ${title}${NOCOLOR}" 2>> "${gen_log}"

    sleep 1

    #Set doDV for later if statement, so only DV Movies will get metadata extracted
    if [[ ${dov} == "true" ]] && [[ $(mediainfo --Output=Video\;%HDR_Format% "${orig_file}" | grep "Dolby Vision") ]]; then
      doDV="true"
    else
      doDV="false"
    fi

    echo -e "${ORANGE}DoDV is: ${doDV}${NOCOLOR}"  2>> "${gen_log}"


    # Set resolution string for filename in orig resolution
    res_str=${res_height}"p"

    # Transcode file to container

      transcode "${orig_file}" "${target_dir_movie}" "${orig_scale}" "${res_str}"


    sleep 1


    # Now do all of this again in FHD.
    if [[ ${res_width} -gt 1920 ]] && [[ ${only_orig_res} != "true" ]]; then

      # Reset Variables
      trans_log=
      fhd_run="true"

        transcode "${orig_file}" "${target_dir_movie}" "${fhd_scale}" "1080p"


      # extract DV metadate if needed/specified
      # ignore overwrite for this second extraction
      overwrite_temp="$overwrite"
      overwrite="false"

      # Delete non DV Version
      if [[ ${onlyDVmovie} == "true" ]] && [[ $doDV == "true" ]]; then
        echo -e "${ORANGE}Deleting non DV Movie:${NOCOLOR}" 2>> "${gen_log}"
        rm "${trans_movie}" -v 2>> "${gen_log}"
      else
        echo -e "${ORANGE}Keeping non DV Movie Version.${NOCOLOR}" 2>> "${gen_log}"
      fi
    fi

    # Delete tmp files
    if [[ ${cleanup} == "true" ]]; then
      echo -e "${ORANGE}Deleting tmp files:${NOCOLOR}" 2>> "${gen_log}"
      rm "${working_dir_movie}" -rv 2>> "${gen_log}"
    fi

    # Delete log files
    if [[ $succ_str =~ 2 ]] || [[ $keep_logs == "true" ]]; then
      echo -e "${ORANGE}Keeping all logs.${NOCOLOR}" 2>> "${gen_log}"
    else
      echo -e "${Orange}Deleting verbose logs:${NOCOLOR}" 2>> "${gen_log}"
      for log in "${log_dir_movie_date}/*.log"; do
        if [[ ! "$log" == "$gen_log" ]]; then
          rm "$log" -v 2>> "${gen_log}"
        fi
      done
    fi
  else
    echo -e "${orig_file} was already transcoded or filtered" 2>> "${gen_log}"
  fi

done
