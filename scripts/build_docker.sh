#!/bin/sh -uex

# Build Axentro static binaries for GNU/Linux x86_64 via Docker

CRYSTAL_VER="0.36.1-1"
READLINK=`which readlink`

MY_DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
test -d $MY_DIR/../bin || mkdir $MY_DIR/../bin
BIN_DIR=$(cd $MY_DIR/../bin && pwd -P)

cd "$BIN_DIR"

if [ -d Axentro ]; then
  git -C Axentro clean -fd
else
  git clone https://github.com/Axentro/Axentro.git
fi

if [ ! -d "crystal-${CRYSTAL_VER}" ]; then
  curl -L -o crystal-${CRYSTAL_VER}-linux-x86_64.tar.gz https://github.com/crystal-lang/crystal/releases/download/${CRYSTAL_VER%%-*}/crystal-${CRYSTAL_VER}-linux-x86_64.tar.gz
  tar -xzvf crystal-${CRYSTAL_VER}-linux-x86_64.tar.gz
fi

########################
# ubuntu:16.04
########################
docker run --rm -it -v $PWD:/mnt ubuntu:16.04 /bin/bash -c "
adduser --disabled-password --shell /bin/bash --gecos \"User\" $USER
set -x ;
export PATH=/mnt/crystal-${CRYSTAL_VER}/bin:\$PATH ;
apt update -qq ;
DEBIAN_FRONTEND=\"noninteractive\" TZ=\"Europe/London\" apt install -y curl libsqlite3-dev libevent-dev libpcre3-dev libssl-dev libxml2-dev lib