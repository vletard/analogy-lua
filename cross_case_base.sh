#!/bin/bash

if (( $# != 3 ))
then
  echo "Usage: $0 KEY_FILE VALUE_FILE SOURCE_OUTPUT"
  exit
fi

tab=$(echo -e "\t")
IFS="
"

in_base=$1
out_base=$2
cube_out=$3

if [ "$(wc -l < $in_base)" != "$(wc -l < $out_base)" ]
then
  echo "Input files have different number of lines."
  exit
fi

total_triples=$(( $(grep -v "^$" < $in_base | wc -l) ** 3 ))
start_time=$(date "+%s")

echo -n > $cube_out

counter=1
./genere_triples.sh $in_base $out_base | while read line
do
  input=$(echo $line | cut -f-3 -d"$tab" | ./solve_inline_triple.lua)
  if [ "$input" != "" ]
  then
    output=$(echo $line | cut -f4- -d"$tab" | ./solve_inline_triple.lua)
    if [ "$output" != "" ]
    then
      echo $line >> $cube_out
      echo -en "\033[2K\r" >&2
      echo -e "$input\t$output"
    fi
  fi
  now=$(date "+%s")
  estimation=$(( $start_time + ( ( $now - $start_time ) * $total_triples ) / $counter ))
  echo -en "$counter  estimated finishing: $(date -d @$estimation)        \r" >&2
  counter=$((counter+1))
done
