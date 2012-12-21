#!/bin/bash

# Purge all of the teams, scores and loaded robots, ready to start a new tournament.

pushd "$(dirname $(readlink -f $0))" >/dev/null
cd ..

echo "This will DELETE all robots, teams and scores"
echo "Are you sure? [y/N]"
read answer
if [[ $answer == "Y" || $answer == "y" ]]; then
  rm -rf scores/* teams/* robots/*
  touch ./tmp/restart.txt
fi

popd >/dev/null
