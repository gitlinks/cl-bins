#!/usr/bin/env bash

current_dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
if [ ! -d "~/.gitlinks" ]; then
	mkdir ~/.gitlinks
fi

cd ~/.gitlinks
curl -O  https://gitlinks.github.io/cl-bins/latest/hermes-cl.tar.gz
tar xzf hermes-cl.tar.gz
cd $current_dir
