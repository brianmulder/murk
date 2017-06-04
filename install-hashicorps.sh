#!/bin/sh

# Download, verify and install an Hashicorp binary distribution.
# POSIX scripting.

set -e
set -u

REQUIRED_DEPENDENCIES="gpg shasum unzip"

HASHICORP_RELEASES=https://releases.hashicorp.com
HASHICORP_GPG_KEY=https://keybase.io/hashicorp/pgp_keys.asc?fingerprint=\
91a6e7f85d05c65630bef18951852d87348ffc4c

show_help() {
cat << EOF
Usage: ${0##*/} [-hoaid] -v VERSION TOOL
Install the specified Hashicorp TOOL, verifying the checksum and signature.

  -h                      display this help and exit
  -v VERSION              The version of Hashicorp software to download.
  -o OPERATING_SYSTEM     Linux, Darwin etc....
  -a ARCHITECTURE         amd64, arm, 386, etc...
  -i INSTALL_LOCATION     /usr/local/bin by default
  -d                      debug mode i.e. 'set -x'

Hashicorp releases: ${HASHICORP_RELEASES}
Hashicorp GPG key: ${HASHICORP_GPG_KEY}
Hashicorp Security: https://www.hashicorp.com/security/
Script dependencies: ${REQUIRED_DEPENDENCIES}
EOF
}

debug() {
  set -x
}

# Defaults
operating_system=$(uname | tr '[:upper:]' '[:lower:]')
architecture=$(uname -m | sed 's/x86_64/amd64/')
install_location=/usr/local/bin

OPTIND=1

while getopts hv:o:a:i:d opt; do
  case $opt in
    h)
       show_help
       exit 0
       ;;
    v) version=$OPTARG
       ;;
    o) operating_system=$(echo $OPTARG | tr '[:upper:]' '[:lower:]')
       ;;
    a) architecture=$OPTARG
       ;;
    i) install_location=$OPTARG
       ;;
    d)
       debug
       ;;
    *)
       show_help >&2
       exit 1
       ;;
  esac
done
shift "$((OPTIND-1))" # Shift off the options and optional --.

tool="$@"
version=${version?"Version not specified"}
checksums=$HASHICORP_RELEASES/$tool/$version/${tool}_${version}_SHA256SUMS
signatures=$HASHICORP_RELEASES/$tool/$version/${tool}_${version}_SHA256SUMS.sig
archive=$HASHICORP_RELEASES/$tool/$version/\
${tool}_${version}_${operating_system}_${architecture}.zip

################################################################################
# Check that a command (binary, function or builtin) is available. Fail if not.
# Globals:
#   None
# Arguments:
#   name: The name of the dependency
# Returns:
#   None
################################################################################
fail_dependency() {
  _name=$1
  command -v $_name >/dev/null 2>&1 || {
    echo >&2 "${_name} not available. Aborting."
    exit 1
  }
}

################################################################################
# Check that all the required softwares are available.
# Globals:
#   REQUIRED_DEPENDENCIES
# Arguments:
#   None
# Returns:
#   None
################################################################################
ensure_dependencies() {
  for _dep in $REQUIRED_DEPENDENCIES; do
    fail_dependency $_dep
  done
}

################################################################################
# Download a file from the web. Will fail if neither curl nor wget can be used.
# Globals:
#   None
# Arguments:
#   url  - URL to download from.
#   path - Where to place the file. Default to current directoy.
# Returns:
#   None
################################################################################
download() {
  _url=${1?"No URL specified for download"}
  _path=${2:-"$(pwd)/$(basename $_url)"}
  if command -v curl >/dev/null 2>&1; then
    _status_code=$(curl --silent --output $_path --write-out "%{http_code}" $_url)
    if test $_status_code -ne 200; then
      echo >&2 "Non 200 status code from curl for url ${_url}. Aborting."
      exit 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    wget --quiet --output-document $_path $_url
  else
    echo >&2 "Neither wget nor curl found. Aborting."
    exit 1
  fi
}

################################################################################
# Performs an installation from scratch. From web to downloaded and installed.
# Globals:
#   HASHICORP_GPG_KEY
#   HASHICORP_RELEASES
#   tool
#   version
#   operating_system
#   architecture
#   checksums
#   signatures
#   archive
#   tempdir
#   install_location
# Arguments:
#   None
# Returns:
#   None
################################################################################
install() {
  set -u

  if [[ ! -d ${install_location} ]]; then
    echo >&2 "INSTALL_LOCATION: ${install_location} is not a directory. Aborting."
    exit 1
  fi

  cd $tempdir

  echo "Download softwares... ${HASHICORP_RELEASES}/$tool/$version/..."
  downloads="$checksums $signatures $archive"
  for d in ${downloads}; do
    download $d
  done

  echo "Verify signatures... ${HASHICORP_GPG_KEY}"
  download $HASHICORP_GPG_KEY $(pwd)/hashicorp.asc
  gpg --quiet --import hashicorp.asc
  gpg --quiet --verify ${tool}_${version}_SHA256SUMS.sig ${tool}_${version}_SHA256SUMS

  echo "Check hashsums... $(cat ${tool}_${version}_SHA256SUMS \
    | grep ${tool} | grep ${operating_system} | grep -F ${architecture}.zip \
    | shasum -a 256 -c -)"

  go_binary=$(unzip ${tool}_${version}_${operating_system}_${architecture}.zip \
    | grep "inflating: $tool" \
    | cut -d ':' -f2 \
    | xargs
  )

  echo "Install ${go_binary} in ${install_location}"
  mv ${go_binary} ${install_location}

  cd ..
}

tempdir=$(mktemp -d ./.tmp.XXX)
trap "{ rm -fr $tempdir; }" INT TERM EXIT
ensure_dependencies
install

exit 0

