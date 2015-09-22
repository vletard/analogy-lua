#!/bin/bash

if (( $# < 3 ))
then
  echo "Usage: $0 KEY_FILE VALUE_FILE TEST_FILE [ADDITIONAL_TEST_FILES]" >&2
  exit
fi

keys=$1
shift
values=$1
shift

CB_number=$(cat $keys $values | md5sum)
CB_number=${CB_number:0:7}

PROG_number=$(git log | grep commit | head -n 1 | cut -f2 -d' ')
PROG_number=${PROG_number:0:7}

echo "  CB_number: $CB_number"
echo "PROG_number: $PROG_number"

while [[ "$1" != "" ]]
do

  file=$(echo $1 | rev | cut -f1 -d"/" | rev)
  #root=$(echo $1 | rev | cut -f2- -d"/" | rev)
  root=/tmp/
  
  overwrite=false
  
  for strategy in intra inter both singletons
  do
    for dynamic in true false
    do
      output_file="$root/log_PROG${PROG_number}_CB${CB_number}_${file}_$strategy"
      if $dynamic
      then
        output_file=${output_file}_dynamic
      fi
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
          *) echo "aborting"; exit ;;
        esac
      fi
      if $dynamic
      then
        echo "Running: ./main.lua $keys $values $strategy dynamic < $1 > $output_file"
        time ./main.lua $keys $values $strategy dynamic < $1 > $output_file
      else
        echo "Running: ./main.lua $keys $values $strategy < $1 > $output_file"
        time ./main.lua $keys $values $strategy < $1 > $output_file
      fi
      grep totaltime $output_file > ${output_file}_time
      grep final $output_file | cut -b 7- > ${output_file}_results
    done
  done

  shift
done
