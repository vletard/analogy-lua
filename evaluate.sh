#!/bin/bash

if (( $# <= 1 ))
then
  echo "Test file(s) missing (requests)" >&2
  exit
fi

while [[ "$1" != "" ]]
do

  file=$(echo $1 | rev | cut -f1 -d"/" | rev)
  #root=$(echo $1 | rev | cut -f2- -d"/" | rev)
  root=/tmp/
  
  overwrite=false
  
  read -p "Name of the case base version: " name
  
  for strategy in intra inter both singletons
  do
    output_file="$root/results_cb${name}_${file}_$strategy"
    if test -f "$output_file" && ! $overwrite
    then
      read -sn 1 -t 10 -p "Output file $output_file already exists, are you sure you want to overwrite it ? (y)es/(n)o/(a)lways/(C)ancel" ans
      echo
      if (( $? == 142 ))
      then
        ans=C
      fi
      case $ans in
        "y"|"Y") echo "overwriting" ;;
        "n"|"N") echo "skipping file"; continue ;;
        "a"|"A") echo "overwriting all files"; overwrite=true ;;
        *) echo "aborting"; break ;;
      esac
    fi
    time ./main.lua $strategy < $1 > $output_file
  done

  shift
done
