#!/usr/bin/env bash
#
# Convert pictures to webp format in batches.
# 
# Ugly, should use python in the beginning.

#----------------------------------------------------------
# fail fast
set -Eeuo pipefail

# set global var, default value
if [[ $(uname) = "Darwin" ]]; then
  OSNAME="MacOS"
elif [[ $(uname) = "Linux" ]]; then
  OSNAME=$(cat /etc/*release | grep -E ^ID= | cut -f2 -d"=")
fi
readonly OSNAME
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd -P)
readonly SCRIPT_DIR
INPUT_DIR=${SCRIPT_DIR}
OUTPUT_DIR= # null, use the source file location.
RATIO=75
RECURSIVE=false

#----------------------------------------------------------
# functions

#######################################
# show help message function ('-h')
#######################################
help_message() {
  cat <<EOF
A simple converter that can batch convert images to webp format.
----
usage: converter.sh [-h] [-d DIR] [-o DIR] [-q RATIO] [-r] [-y]

optional arguments:
-h       Show the help message.
-d       Specify the input directory, default is the current directory.
-o       Specify the output directory, default is the source file location
-q       Quality ratio (0 ~ 100), default is 75.
-r       Process recursively.
-y       Skip confirmation and convert images in the current directory only.
EOF
  exit
}

#######################################
# error message
#######################################
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

#######################################
# check file format
# Globals:
#   None
# Arguments:
#   $1 - file path
# Returns:
#   0 - images
#   1 - other files
#######################################
is_image() {
  local suffix="${1##*.}"
  case ${suffix} in
    "jpg" | "jpeg")
      return 0 ;;
    "JPG" | "JPEG")
      return 0 ;;
    "png" | "PNG")
      return 0 ;;
    "tif" | "tiff")
      return 0 ;;
    "TIF" | "TIFF")
      return 0 ;;
    *)
      return 1 ;;
  esac
}

#######################################
# recursive function
# 
# If it is a folder, continue recursively;
# If it is a picture, convert.
#
# Globals:
#   IFS
#   RECURSIVE
#   OUTPUT_DIR
#   RATIO
# Arguments:
#   $1 - input dir path
# Returns:
#   None
#######################################
traverse_files() {
  # change IFS
  local savedifs=${IFS}
  IFS=$'\n'

  # check the path ends with "/" or not
  if [[ ${1:0-1:1} = "/" ]]; then
    local path="$1*"
  else
    local path="$1/*"
  fi

  # traverse files
  for file in ${path}; do # do not use $(ls ...)
    if [[ -d "${file}" && ${RECURSIVE} = true ]]; then # if it is dir
      traverse_files "${file}"
    elif is_image "${file}" && [[ -f "${file}" && -r "${file}" ]]; then # if it is image
      if [[ -d "${OUTPUT_DIR}" ]]; then # if specify '-o'
        # extract the image file names and rename it to ".webp"
        local input_filename
        input_filename=$(echo "${file##*/}" | cut -f1 -d".")".webp"
        # add output folder prefix
        if [[ ${OUTPUT_DIR:0-1:1} = "/" ]]; then # check the path ends with "/" or not
          local output_file_name="${OUTPUT_DIR}${input_filename}"
        else
          local output_file_name="${OUTPUT_DIR}/${input_filename}"
        fi
      else
        local output_file_name="${file%.*}.webp"
      fi

      # use cwebp to convert images
      # -mt: multi-thread
      cwebp -o "${output_file_name}" -q ${RATIO} -quiet -mt -- "${file}"
    elif is_image "${file}" && [[ -f "${file}" && ! -r "${file}" ]]; then # if it is image and can not be read
      err "'${file}' can not be read!"
    fi
  done

  # restore IFS
  IFS=${savedifs}
}

#----------------------------------------------------------
# main

# if no input arguments
if [[ $# -eq 0 ]]; then
  echo "Execute the conversion (only in the current directory)[Y|N]?"
  read -rn1 execarg
  case ${execarg} in
    Y | y)
      echo
      ;;
    N | n)
      echo
      err "give up."
      exit 1
      ;;
    *)
      echo
      err "Unknown input."
      exit 1
      ;;
  esac
else
  # get user input argument
  while getopts "d:ho:q:ry" opt; do
    case ${opt} in
      d)
        INPUT_DIR=${OPTARG} ;;
      h)
        help_message ;; # help function
      o)
        OUTPUT_DIR=${OPTARG} ;;
      q)
        RATIO=${OPTARG} ;;
      r)
        RECURSIVE=true ;;
      y)
        ;;
      *)
        err "Unknown option."
        exit 1
        ;;
    esac
  done
fi

# arguments check
if [[ ! -d "${INPUT_DIR}" ]]; then
  err "Input directory path[-d]: '${INPUT_DIR}' does not exist!"
  exit 1
elif [[ ${OUTPUT_DIR} && ! -d "${OUTPUT_DIR}" ]]; then
  mkdir "${OUTPUT_DIR}" # create output dir
elif [[ ${RATIO} -gt 100 || ${RATIO} -lt 0 ]]; then
  err "Quality ratio[-q] should be between 0 and 100!"
  exit 1
fi

# execute conversion
if type cwebp > /dev/null 2>&1; then
  # cwebp exists
  traverse_files "${INPUT_DIR}"
else
  # cwebp does not exist, install hint
  err "Sorry, 'cwebp' is not installed in the system."
  case ${OSNAME} in
    "MacOS")
      err "Use 'brew install webp' to install." ;;
    "ubuntu" | "debian")
      err "Use 'apt install webp' to install." ;;
    "\"centos\"")
      err "Use 'yum install libwebp-tools' to install." ;;
    "fedora")
      err "Use 'dnf install libwebp-tools' to install." ;;
    *)
      err "Please download manually from https://developers.google.com/speed/webp/download." ;;
  esac
fi

#----------------------------------------------------------
# TODO: Use curl to download cwebp.
# TODO: convert '.webp' to 'png', 'jpg'...
