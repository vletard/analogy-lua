#!/bin/bash

HELP="
Usage: $0 [OPTION]... [REQUEST_FILE]
Launches the system to answer the requests given in REQUEST_FILE or standard input.

OPTIONS
  -h, --help
         prints this help summary
  -d, --deviation=N
         allows deviations while searching *and* solving
      --deviation-search=N
         allows the count sum to deviate of N while searching the count-tree
      --deviation-solve=N
         allows the deviations up to N while solving analogies
  -s, --source-examples=FILE
         looks for source sequences in FILE
  -t, --target-examples=FILE
         looks for target sequences in FILE
  -p, --example-base-pattern=PATTERN
         gets source and target sequences respectively from PATTERN.in and PATTERN.out
  -i, --interactive
         the session is interactive
  -a, --analogical-mode=MODE
         sets the analogical mode to one of \"singletons\", \"inter\", \"intra\", or \"both\"
         \"both\" is default
  --segmentation-mode=MODE
         sets the segmentation mode to one of \"static\", \"static-cut\", \"dynamic-cube\", or \"dynamic-square\"
         \"static\" is default, and modifying it is currently DISCOURAGED
  --source-segmentation=MODE
         sets the segmentation of source sentences to one of \"words\", \"pounds\", \"words+spaces\",
         or \"characters\"
         \"words\" is default
  --target-segmentation=MODE
         sets the segmentation of target sentences to one of \"words\", \"pounds\", \"words+spaces\",
         or \"characters\"
         \"characters\" is default
  --time-limit-indirect=SECONDS
         sets the time limit in seconds for searching indirect analogies
"

# Default/initial values
example_base_source=
example_base_target=
source_segmentation=words
target_segmentation=words

analogical_mode=both
deviation_search=0
deviation_solve=0
segmentation_mode=static
time_limit_indirect=-1

interactive=false
input_file=

######################################################
# Parsing the command line
TEMP=`getopt -o d:s:t:p:a:ih --long deviation:,deviation-search:,deviation-solve:,example-base-pattern:,source-examples:,target-examples:,interactive,source-segmentation:,target-segmentation:,analogical-mode:,segmentation-mode:,time-limit-indirect:,help -n "$0" -- "$@"`

if [ $? != 0 ] ; then echo "Abandon" >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
	case "$1" in
    -p|--example-base-pattern)
      example_base_source=$2.in.txt
      example_base_target=$2.out.txt
      shift 2 ;;
    -s|--source-examples)
      example_base_source=$2
      shift 2 ;;
    -t|--target-examples)
      example_base_target=$2
      shift 2 ;;
    -d|--deviation)
      deviation_search=$2
      deviation_solve=$2
      shift 2 ;;
    --deviation-search)
      deviation_search=$2
      shift 2 ;;
    --deviation-solve)
      deviation_solve=$2
      shift 2 ;;
    -i|--interactive)
      interactive=true
      shift ;;
    --source-segmentation)
      source_segmentation=$2
      shift 2 ;;
    --target-segmentation)
      target_segmentation=$2
      shift 2 ;;
    -a|--analogical-mode)
      analogical_mode=$2
      shift 2 ;;
    --time-limit-indirect)
      time_limit_indirect=$2
      shift 2 ;;
    --segmentation-mode)
      echo "Changing the segmentation mode before the C version is out is discouraged." >&2
      sleep 2
      segmentation_mode=$2
      shift 2 ;;
		-h|--help)
      echo "$HELP"
      exit 0 ;;
		--) shift ; break ;;
		*) echo "Internal error!" ; exit 1 ;;
	esac
done

######################################################

input="stdin"
if (($# != 0))
then
  input_file="$1"
  input="$input_file"
fi

if [ "$example_base_source" == "" ] || [ "$example_base_target" == "" ]
then
  echo "Source and target example base files must be specified." >&2
  echo "$HELP" >&2
  exit 1
fi

# Printing a summary
echo "
input:               $input
example_base_source: $example_base_source
example_base_target: $example_base_target
source_segmentation: $source_segmentation
target_segmentation: $target_segmentation
analogical_mode:     $analogical_mode
deviation_search:    $deviation_search
deviation_solve:     $deviation_solve
segmentation_mode:   $segmentation_mode
interactive:         $interactive
time_limit_indirect: $time_limit_indirect
" >&2

cat $input_file | ./ilar.lua -- "$example_base_source" "$example_base_target" "$analogical_mode" "$segmentation_mode" "$interactive" "$deviation_search" "$deviation_solve" "$source_segmentation" "$target_segmentation" "$time_limit_indirect"
