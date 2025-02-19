#!/usr/bin/env bash

echo "Retrieving dependencies"
mix deps.get

echo "Generating executable"
mix escript.build

echo "Setting path"
cp "aedis" "/usr/local/bin"

echo "Ready to use, enjoy!"