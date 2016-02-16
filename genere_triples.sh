#!/bin/bash

if (( $# != 2 ))
then
  echo "Usage: $0 KEY_FILE VALUE_FILE"
  exit
fi

IFS="
"

while read input1 <&3 && read output1 <&4
do
  if [ "$input1" != "" ] && [ "$output1" != "" ]
  then
    while read input2 <&5 && read output2 <&6
    do
      if [ "$input2" != "" ] && [ "$output2" != "" ]
      then
        while read input3 <&7 && read output3 <&8
        do
          if [ "$input3" != "" ] && [ "$output3" != "" ]
          then
            echo -e "$input1\t$input2\t$input3\t$output1\t$output2\t$output3"
          fi
        done 7<$1 8<$2
      fi
    done 5<$1 6<$2
  fi
done 3<$1 4<$2
