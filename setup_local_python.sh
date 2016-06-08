#!/bin/bash

## xcode-select --install ## installs gcc and other deps

set -u
set -e

function usage() {
  echo "$(basename $0) <installation dir>"
}

if [ ! $# -le 1 ]; then
  usage
  exit 1
fi

OLD_PWD=$(pwd)
TMP_DIR=$(mktemp -dt setup_local_python.XXXXXX)
echo "tmp dir $TMP_DIR"

function err_exit_term() {
  echo "cleaning up tmp dir $TMP_DIR"
  rm -rf $TMP_DIR
  cd $OLD_PWD
}

trap err_exit_term ERR EXIT TERM

# setup OS X verion
typeset -x MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion)

# setting up local dirs
typeset -x LOCAL_DIR="${1:-$HOME/local}"
typeset -x OPENSSL_ROOT_DIR="$LOCAL_DIR/openssl"
typeset -x OPENSSL_CA_PATH="$LOCAL_DIR/openssl/certs"
typeset -x PYTHON_ROOT_DIR="$LOCAL_DIR/python"
typeset -x CURL_ROOT_DIR="$LOCAL_DIR/curl"
typeset -x READLINE_ROOT_DIR="$LOCAL_DIR/readline"
typeset -x CORE_UTILS_ROOT_DIR="$LOCAL_DIR/coreutils"
typeset -x SSL_CERT_FILE="$OPENSSL_CA_PATH/cacert.pem"

mkdir -p "$LOCAL_DIR"
cd $LOCAL_DIR


mkdir -p "$OPENSSL_CA_PATH"
cd $OPENSSL_CA_PATH
echo "downloading certs into $OPENSSL_CA_PATH"
## https://curl.haxx.se/docs/caextract.html contains info on how to gen these
## using a conversion tool
curl -O -s https://curl.haxx.se/ca/cacert.pem


cd $TMP_DIR
echo "downloading openssl, compiling and installing in $OPENSSL_ROOT_DIR"
curl -O -s https://www.openssl.org/source/openssl-1.0.2h.tar.gz
tar -xvzf openssl-1.0.2h.tar.gz
cd openssl-1.0.2h
./configure --openssldir="$OPENSSL_ROOT_DIR" darwin64-x86_64-cc
make depend
make
make install
#sudo ln -s /Users/varun.tamminedi/local/openssl /usr/local/openssl
# security find-certificate -a -p /Library/Keychains/System.keychain > /usr/local/openssl/ssl/cert.pem
# security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain >> /usr/local/openssl/ssl/cert.pem


#cd $TMP_DIR
#echo "downloading curl, compiling and installing in $CURL_ROOT_DIR"
#curl -O -s https://curl.haxx.se/download/curl-7.49.1.tar.gz
#tar -xvzf curl-7.49.1.tar.gz
#cd curl-7.49.1
#./configure --prefix="$CURL_ROOT_DIR" --with-darwinssl ##--with-ssl="$OPENSSL_ROOT_DIR" --with-ca-bundle="$SSL_CERT_FILE" --with-ca-path="$SSL_CERT_DIR"
#make
#make install


cd $TMP_DIR
echo "downloading readline, compiling and installing in $READLINE_ROOT_DIR"
curl -O -s http://git.savannah.gnu.org/cgit/readline.git/snapshot/readline-master.tar.gz
tar -xvzf readline-master.tar.gz
cd readline-master
ARCHFLAGS="-arch x86_64" ./configure --prefix "$READLINE_ROOT_DIR"
make
make install

cd $TMP_DIR
echo "downloading coreutils, compiling and installing in $CORE_UTILS_ROOT_DIR"
curl -O -s http://ftp.gnu.org/gnu/coreutils/coreutils-8.25.tar.xz
tar -xvzf coreutils-8.25.tar.xz
cd coreutils-8.25
ARCHFLAGS="-arch x86_64" ./configure --prefix "$CORE_UTILS_ROOT_DIR"
make
make install

cd $TMP_DIR
echo "downloading python, compiling and installing in $PYTHON_ROOT_DIR"
curl -O -s https://www.python.org/ftp/python/2.7.11/Python-2.7.11.tgz
tar -xvzf Python-2.7.11.tgz
cd Python-2.7.11
sed -i '' 's|#_socket socketmodule.c timemodule.c|_socket socketmodule.c timemodule.c|g' Modules/Setup.dist
sed -i '' "s|#SSL=/usr/local/ssl|SSL=$OPENSSL_ROOT_DIR|g" Modules/Setup.dist
sed -i '' 's|#_ssl _ssl.c \\|_ssl _ssl.c \\|g' Modules/Setup.dist
sed -i '' 's|#	-DUSE_SSL -I$(SSL)/include -I$(SSL)/include/openssl \\|	-DUSE_SSL -I$(SSL)/include -I$(SSL)/include/openssl \\|g' Modules/Setup.dist
sed -i '' 's|#	-L$(SSL)/lib -lssl -lcrypto|	-L$(SSL)/lib -lssl -lcrypto|g' Modules/Setup.dist
sed -i '' 's|#readline readline.c -lreadline -ltermcap|readline readline.c -lreadline -ltermcap|g' Modules/Setup.dist
LD_LIBRARY_PATH="$READLINE_ROOT_DIR/lib" ./configure --prefix "$PYTHON_ROOT_DIR" --with-libs="-lexpat -lncurses -lreadline"
make
make install

typeset -x OPENSSL_PATH="$OPENSSL_ROOT_DIR/bin"
typeset -x PYTHONPATH="$PYTHON_ROOT_DIR/bin"
typeset -x CORE_UTILS_PATH="$CORE_UTILS_ROOT_DIR/bin"
typeset -x PATH="$OPENSSL_PATH:$PYTHONPATH:$CORE_UTILS_PATH:$PATH"

which python
echo "installing setup_tools"
curl https://bootstrap.pypa.io/ez_setup.py -o - | python
echo "installing pip and virtualenv and virtualenvwrapper"
python -m easy_install pip
python -m pip install virtualenv virtualenvwrapper

set +u
# setting up virualenvwrapper
typeset -x WORKON_HOME="$HOME/venv"
source "$PYTHONPATH/virtualenvwrapper.sh"


echo
echo
echo


## cleanup PATH
export PATH=$(echo "$PATH" | awk -v RS=':' -v ORS=":" '!a[$1]++')

cat << EOF
-------------------------------------------------------
## ADD the following lines to your shell profile
# setting PATH for Python 2.7.11 and depending libs
typeset -x OPENSSL_PATH="$OPENSSL_ROOT_DIR/bin"
typeset -x PYTHONPATH="$PYTHON_ROOT_DIR/bin"
typeset -x CORE_UTILS_PATH="$CORE_UTILS_ROOT_DIR/bin"
typeset -x PATH="$PATH"

# for python ssl cert support
typeset -x SSL_CERT_FILE="$OPENSSL_CA_PATH/cacert.pem"

# setting up path for man pages
typeset -x MANPATH="$OPENSSL_ROOT_DIR/ssl/man:$MANPATH"

# setting up virtualenv
typeset -x WORKON_HOME="$HOME/venv"
source "$PYTHONPATH/virtualenvwrapper.sh"
--------------------------------------------------------



-------------------------------------------------------
## Run the following commands to setup ansible
mkvirtualenv rackspace
workon racksapce
pip install -r ansible_requirements.txt
## or (one of the pip commands will do)
pip install python-novaclient==2.35.0 anisble==1.7.2 pyrax==1.7.2 rackspace-novaclient rackspace-neutronclient
deactivate
-------------------------------------------------------
EOF
