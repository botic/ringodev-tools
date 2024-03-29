#!/usr/bin/env bash

## Script based on NodeJS release.sh and adapted for RingoJS. Usage:
## sign-release.sh VERSION
##
## Node.js is licensed for use as follows:
##
## Copyright Node.js contributors. All rights reserved.
##
## Permission is hereby granted, free of charge, to any person obtaining a copy
## of this software and associated documentation files (the "Software"), to
## deal in the Software without restriction, including without limitation the
## rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
## sell copies of the Software, and to permit persons to whom the Software is
## furnished to do so, subject to the following conditions:
##
## The above copyright notice and this permission notice shall be included in
## all copies or substantial portions of the Software.
##
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
## IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
## AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
## LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
## FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
## IN THE SOFTWARE.

set -e

LANG="en"

if [ "X${1}" == "X" ]; then
  echo "Please supply a version string to sign"
  exit 1
fi

################################################################################
## Select a GPG key to use

echo "# Selecting GPG key ..."

gpgkey=$(gpg --list-secret-keys --keyid-format SHORT | awk -F'( +|/)' '/^(sec|ssb)/{print $3}')
keycount=$(echo "$gpgkey" | wc -w)

if [ "$keycount" -eq 0 ]; then
  # shellcheck disable=SC2016
  echo 'Need at least one GPG key, please make one with `gpg --gen-key`'
  echo 'You will also need to submit your key to a public keyserver, e.g.'
  echo '  https://sks-keyservers.net/i/#submit'
  exit 1
elif [ "$keycount" -ne 1 ]; then
  printf "You have multiple GPG keys:\n\n"

  gpg --list-secret-keys

  keynum=
  while [ -z "${keynum##*[!0-9]*}" ] || [ "$keynum" -le 0 ] || [ "$keynum" -gt "$keycount" ]; do
    echo "$gpgkey" | awk '{ print NR ") " $0; }'
    printf 'Select a key: '
    read -r keynum
  done
  echo ""
  gpgkey=$(echo "$gpgkey" | sed -n "${keynum}p")
fi

gpgfing=$(gpg --keyid-format 0xLONG --fingerprint "$gpgkey" | grep 'Key fingerprint =' | awk -F' = ' '{print $2}' | tr -d ' ')

echo "Using GPG key: $gpgkey"
echo "  Fingerprint: $gpgfing"

################################################################################
## Create and sign checksums file for a given version

function sign {
  echo "# Creating SHASUMS256.txt ..."

  local version=$1

  tmpdir="/tmp/_ringojs.$$"
  mkdir -p $tmpdir

  shafile="SHASUMS256-${version}.txt"

  checksumpath="https://github.com/ringo/ringojs/releases/download/v${version}/${shafile}"
  echo "# Loading $checksumpath"
  curl -sL ${checksumpath} -o ${tmpdir}/${shafile}

  echo "# Signing SHASUMS for ${version}..."

  gpg -b --default-key $gpgkey --clearsign --digest-algo SHA256 ${tmpdir}/${shafile}
  gpg -b --default-key $gpgkey --detach-sign --digest-algo SHA256 ${tmpdir}/${shafile}

  echo "Wrote to ${tmpdir}/"

  echo "Your signed ${tmpdir}/${shafile}.asc:\n"

  cat ${tmpdir}/${shafile}.asc

  echo ""
}

sign $1
exit 0