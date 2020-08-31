#!/bin/bash
# Pre-requisites: prior to running, ensure that the following are installed:
#  - ffmpeg
#  - ffprobe
#  - youtube-dl ($ brew install youtube-dl)
#
# Usage:
#   $ . youtube-trim.sh
#   $ trim_video

# Try audio format 18 if bestaudio doesn't work.
AUDIO_FORMAT=bestaudio
VIDEO_FORMAT=bestvideo

green="\033[0;32m"
red="\033[0;31m"
yellow="\033[1;33m"
nc='\033[0m'

function usage() {
  echo -e "${yellow}Usage:${nc} trim_video <video_url> <start_time> <end_time> <output_filename>" 1>&2;
  echo -e "${yellow}Overriding formats:${nc} Set the environment variables AUDIO_FORMAT (${AUDIO_FORMAT}) and VIDEO_FORMAT (${VIDEO_FORMAT})." 1>&2;
}

# Trims the given video from the given start time to end time.
#
# Args:
#   VIDEO_URL ($1)
#   START_TIME ($2)
#   END_TIME ($3)
#   OUTPUT_FILENAME ($4)
function trim_video() {
  if [ $# -ne 4 ]; then
    usage
    return 1
  fi
  start_time_hh_mm_ss=$(get_time_hh_mm_ss "${2}")
  start_time_secs=$(get_time_seconds "${start_time_hh_mm_ss}")
  end_time_hh_mm_ss=$(get_time_hh_mm_ss "${3}")
  end_time_secs=$(get_time_seconds "${end_time_hh_mm_ss}")
  duration_secs=$(echo "$end_time_secs - $start_time_secs" | bc)
  duration_hh_mm_ss=$(get_time_hh_mm_ss "${duration_secs}")
  ss_secs=$(get_ss_secs "${start_time_secs}")
  ss_hh_mm_ss=$(get_time_hh_mm_ss "${ss_secs}")
  ss_duration=$(get_ss_duration_secs "${start_time_secs}")
  show_plan_and_wait_with_timeout \
    "${1}" "${start_time_hh_mm_ss}" "${ss_hh_mm_ss}" \
    "${ss_duration}" "${end_time_hh_mm_ss}" \
    "${duration_hh_mm_ss}" "${4}"
  if [ $? -ne 0 ]; then
    echo -e "${red}Aborting.${nc}"
    return 2
  fi
  trim "${1}" "${ss_hh_mm_ss}" "${ss_duration}" \
    "${duration_hh_mm_ss}" "__${4}"
  if [ $? -ne 0 ]; then
    echo -e "${red}FFMPEG Trimming failed. Aborting.${nc}"
    rm "__${4}" 2> /dev/null
    echo -e "${yellow}The URL ${nc}${1}${yellow} provides the following audio and video formats:${nc}"
    youtube-dl --list-formats "${1}"
    echo -e "${yellow}Consider overriding formats:${nc} Set the environment variables AUDIO_FORMAT (${AUDIO_FORMAT}) and VIDEO_FORMAT (${VIDEO_FORMAT})." 1>&2;
    return 3
  fi
  show_trimmed_stats_and_wait "__${4}"
  if [ $? -ne 0 ]; then
    echo -e "${red}Aborting compression.${nc}"
    return 4
  fi
  compress_video "__${4}" "${4}"
  if [ $? -ne 0 ]; then
    echo -e "${red}Video compression failed. Aborting.${nc}"
    rm "__${4}" 2> /dev/null
    return 5
  fi
  rm "__${4}" 2> /dev/null
  echo -e "${green}Trimmed and compressed successfully!${nc}"
  return 0
}

# Trims the given video with given parameters using ffmpeg.
# Pre-requisites: FFMPEG must be installed.
#
# Args:
#   VIDEO_URL ($1)
#   SS_TIME ($2) in format HH:MM:SS.
#   SS_DURATION ($3) in seconds.
#   TRIMMED_DURATION ($4) in format HH:MM:SS.
#   OUTPUT_FILENAME ($5).
#
# Returns:
#   Exit status of 0 if successful.
function trim() {
  video_url=($(youtube-dl -f "${VIDEO_FORMAT}" -g "${1}"))
  audio_url=($(youtube-dl -f "${AUDIO_FORMAT}" -g "${1}"))
  echo -e "${yellow}Video URL (format ${VIDEO_FORMAT}):${nc} ${video_url}"
  echo -e "${yellow}Audio URL (format ${AUDIO_FORMAT}):${nc} ${audio_url}"
  ffmpeg -hide_banner \
    -ss "${ss_hh_mm_ss}" -i "${video_url}" \
    -ss "${ss_hh_mm_ss}" -i "${audio_url}" \
    -map 0:v -map 1:a -ss "${ss_duration}" \
    -t "${duration_hh_mm_ss}" -c:v libx264 -c:a aac \
    "${5}"
}

# Compresses the given video for small, share-able size.
#
# Args:
#   INPUT_VIDEO_FILENAME ($1)
#   OUTPUT_VIDEO_FILENAME ($2)
#
# Returns:
#   Exit status 0, if successful.
function compress_video() {
  ffmpeg -hide_banner \
    -i "${1}" \
    -vf scale=-1:242 \
    -c:v libx264 \
    -crf 26 -preset veryslow \
    -c:a \
    copy "${2}" 
}

# Converts the given timestamp into HH:MM:SS.
#
# Args:
#   TIME_STRING ($1): The time string to be formatted.
#     Could be in the format "HH:MM:SS" or "MM:SS" or "SS".
#
# Returns:
#   Formatted time string, in the format "HH:MM:SS".
#   Return value is printed out to stdout, to be captured by the caller.
function get_time_hh_mm_ss() {
  num_separators=$(echo ${1} | sed -e 's/[^:]//g' | awk '{ print length }')
  if [ $num_separators -eq 0 ]; then
    seconds=$(echo "${1} % 60" | bc)
    minutes=$(echo "(${1} % 3600) / 60" | bc)
    hours=$(echo "${1} / 3600" | bc)
    echo "${hours}:${minutes}:${seconds}"
  elif [ $num_separators -eq 1 ]; then
    echo "00:${1}"
  elif [ $num_separators -eq 2 ]; then
    echo "${1}"
  else
    return 1
  fi
  return 0
}

# Args:
#   TIME_STRING ($1): The time string formatted as "HH:MM:SS".
#
# Returns:
#   The time in seconds (number).
function get_time_seconds() {
  s="${1}:"
  hh_mm_ss_array=();
  while [[ $s ]]; do
    hh_mm_ss_array+=( "${s%%":"*}" );
    s=${s#*":"};
  done;
  echo $(echo "${hh_mm_ss_array[0]}*3600 + ${hh_mm_ss_array[1]}*60 + ${hh_mm_ss_array[2]}" | bc)
  return 0
}


# Args:
#   TIME ($1): The time in seconds.
#
# Returns:
#   The "SS" time to be used for trimming via ffmpeg, in seconds.
#   This is a few seconds earlier than the input TIME, to account for the
#   key frame for the beginning of the video.
function get_ss_secs() {
  time_secs="${1}"
  if (( $(echo "$time_secs > 30" | bc -l) )); then
    echo $(echo "${time_secs} - 30" | bc)
    return 0
  fi
  echo "0"
  return 0
}

# Args:
#   TIME ($1): The time in seconds.
#
# Returns:
#   The duration (in seconds) between the "SS" time and given time.
#   See the documentation for "get_ss(.)" for an overview of what this is.
function get_ss_duration_secs() {
  time_secs="${1}"
  if (( $(echo "$time_secs > 30" | bc -l) )); then
    echo "30"
    return 0
  fi
  echo "${time_secs}"
  return 0
}

# Prints the work plan and gives users 3 seconds to abort, before
# returning.
#
# Args:
#   VIDEO_URL ($1)
#   START_TIME  ($2) in format HH:MM:SS.
#   SS_TIME ($3) in format HH:MM:SS.
#   SS_DURATION ($4) in seconds.
#   END_TIME ($5) in format HH:MM:SS.
#   DURATION ($6) in format HH:MM:SS.
#   OUTPUT_FILENAME ($7) string filename.
#
# Returns:
#  Exit status 0 if it's ok to proceed.
function show_plan_and_wait_with_timeout() {
  printf "${green}"
  echo "Going to trim:"
  printf "${nc}${yellow}"
  echo "    The youtube video: ${1}"
  echo "    From: ${2} (will look for keyframes from ${3}, ${4} seconds earlier.)"
  echo "    To: ${5} (duration ${6})"
  echo "    Output at: ${7}"
  printf "${nc}"
  wait_with_timeout
  return 0
}

function show_trimmed_stats_and_wait() {
  printf "${green}"
  echo "Finished trimming video. Trimmed video stats:"
  printf "${nc}${yellow}"
  ffprobe "${1}" 2>&1 | sed '1,/^Input.*$/d'
  printf "${nc}${green}"
  echo "Going to compress the raw trimmed video."
  printf "${nc}"
  wait_with_timeout
}

function wait_with_timeout() {
  printf "${green}"
  echo -n "Press any key to continue (or Ctrl^C to abort).";
  printf "${nc}"
  for _ in {1..7}; do
    REPLY=""
    read -rs -n1 -t1 || printf ".";
    if [ ! -z "${REPLY}" ]; then
      echo -e "${green}[continuing]${nc}"
      read -e -t1  # Clear the input buffer.
      return 0
    fi
  done;
  echo -e "${green}[continuing]${nc}"
  return 0
}

