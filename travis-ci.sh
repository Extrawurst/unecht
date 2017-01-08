#!/usr/bin/env bash

set -eo pipefail

./assets/compile.sh
if [ ! -z "$(git status -uno -- public | grep modified)" ]; then
    echo 'Forgot to precompile assets?'
    exit 1
fi
dub build --compiler=${DC:-dmd}
./scod serve-html test/test.json &
PID=$!
cleanup() { kill $PID; }
trap cleanup EXIT

wget https://github.com/Medium/phantomjs/releases/download/v2.1.1/phantomjs-2.1.1-linux-x86_64.tar.bz2
tar -C $HOME -jxf phantomjs-2.1.1-linux-x86_64.tar.bz2
export PATH="$HOME/phantomjs-2.1.1-linux-x86_64/bin/:$PATH"

npm install phantomcss -q
if ! ./node_modules/phantomcss/node_modules/.bin/casperjs test test/test.js ; then
    # upload failing screenshots
    cd test/screenshots
    for img in *.{diff,fail}.png; do
        ARGS="$ARGS -F image=@$img"
    done
    ARGS="$ARGS -F build_id=$TRAVIS_BUILD_ID"
    curl -fsSL https://ddox-test-uploads.herokuapp.com $ARGS
    exit 1
fi
