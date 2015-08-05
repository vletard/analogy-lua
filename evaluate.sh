#!/bin/bash

if (( $# != 1 ))
then
  echo "Entrer l'adresse du fichier de test (requêtes)" >&2
  exit
fi

file=$(echo $1 | rev | cut -f1 -d"/" | rev)
root=$(echo $1 | rev | cut -f2- -d"/" | rev)

for strategy in intra inter both singletons
do
  time ./main.lua $strategy < $1 > $root/results_${file}_$strategy
done
