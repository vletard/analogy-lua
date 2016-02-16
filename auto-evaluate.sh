#!/bin/bash

# Data from NELDA v1 (rephrasal biases)
rm -f /tmp/log_*
./evaluate.sh /people/letard/analogy/case_base/2015_05_bash/train/01_l.in.txt /people/letard/analogy/case_base/2015_05_bash/train/01.out.txt /people/letard/analogy/case_base/2015_05_bash/test/{ext01,02}_l.in.txt
mkdir /tmp/cb01
mv /tmp/log_* /tmp/cb01

# Data from NELDA v1 (rephrasal biases) + generation
rm -f /tmp/log_*
./evaluate.sh /people/letard/analogy/case_base/2015_05_bash/train/01.in.g01_l.txt /people/letard/analogy/case_base/2015_05_bash/train/01.out.g01.txt /people/letard/analogy/case_base/2015_05_bash/test/{ext01,02}_l.in.txt
mkdir /tmp/cbg01
mv /tmp/log_* /tmp/cbg01


# Data from Kushman & Barzilay as is
rm -f /tmp/log_*
./evaluate.sh /people/letard/analogy/case_base/regexp/fold/train1.in /people/letard/analogy/case_base/regexp/fold/train1.out /people/letard/analogy/case_base/regexp/fold/test1.in
mkdir /tmp/cbbarzilay
mv /tmp/log_* /tmp/cbbarzilay
rm -f /tmp/log_*
./evaluate.sh /people/letard/analogy/case_base/regexp/fold/train2.in /people/letard/analogy/case_base/regexp/fold/train2.out /people/letard/analogy/case_base/regexp/fold/test2.in
mv /tmp/log_* /tmp/cbbarzilay
rm -f /tmp/log_*
./evaluate.sh /people/letard/analogy/case_base/regexp/fold/train3.in /people/letard/analogy/case_base/regexp/fold/train3.out /people/letard/analogy/case_base/regexp/fold/test3.in
mv /tmp/log_* /tmp/cbbarzilay

# Data from Kushman & Barzilay artificially segmented
rm -f /tmp/log_*
./evaluate.sh /people/letard/analogy/case_base/regexp/fold_seg/train1.in /people/letard/analogy/case_base/regexp/fold_seg/train1.out /people/letard/analogy/case_base/regexp/fold_seg/test1.in
mkdir /tmp/cbbarzilay_custom
mv /tmp/log_* /tmp/cbbarzilay_custom
rm -f /tmp/log_*
./evaluate.sh /people/letard/analogy/case_base/regexp/fold_seg/train2.in /people/letard/analogy/case_base/regexp/fold_seg/train2.out /people/letard/analogy/case_base/regexp/fold_seg/test2.in
mv /tmp/log_* /tmp/cbbarzilay_custom
rm -f /tmp/log_*
./evaluate.sh /people/letard/analogy/case_base/regexp/fold_seg/train3.in /people/letard/analogy/case_base/regexp/fold_seg/train3.out /people/letard/analogy/case_base/regexp/fold_seg/test3.in
mv /tmp/log_* /tmp/cbbarzilay_custom

# Data from NICOLAS (experimenter bias and unique writer bias)
rm -f /tmp/log_*
./evaluate.sh /people/letard/analogy/case_base/nicolas/train.in /people/letard/analogy/case_base/nicolas/train.out /people/letard/analogy/case_base/nicolas/test.in
mkdir /tmp/cbNICOLAS
mv /tmp/log_* /tmp/cbNICOLAS
