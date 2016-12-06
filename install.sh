#!/usr/bin/env bash

echo
echo "Installing Gitlinks CLI, Hermes"

INSTALL_FOLDER=~/.gitlinks

current_dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

if [ ! -d "$INSTALL_FOLDER" ]; then
	mkdir $INSTALL_FOLDER
fi

cd "$INSTALL_FOLDER"
curl -OsSf https://gitlinks.github.io/cl-bins/latest/hermes-cl.tar.gz
tar -xzf $INSTALL_FOLDER/hermes-cl.tar.gz
cd $current_dir

echo
echo "run with $INSTALL_FOLDER/hermes-rust-ci"
echo
