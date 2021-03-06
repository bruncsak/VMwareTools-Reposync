#!/bin/bash
#script to get rh VMware packages from VMware
#v0.8
#
# By Default. This script will not provide any output if things work properly.
# to see what's going on. add a numeric verbosity indicator after the script:
# ./updatevmware.sh 
#    will be silent
# ./updatevmware.sh 1
#    will provide some output.. Higher numbers will provide more verbosity.
#
#
#Copyright 2012 Datapipe
#  Wolf Noble <wnoble@datapipe.com>

GET5="true"
GET6="true"
GETx86_64="true"
GETi686="true"
GETi386="true"
TOPDIR="/repo/vendor/vmware"
DIRLIST=/tmp/vmwaredirs`date +%m%d%y-%H`
VERLIST=/tmp/vmwarevers`date +%m%d%y-%H`
MIRRORSERVERS=("server1.mydomain.com" "server2.mydomain.com")
export TOPDIR
export UPDATEREPO
# Allow overriding the above variables from a configuration file for local customization
[ -e "$0.cfg" ] && . "$0.cfg"
debug=0;
if [ -n "${1:+1}" ]; then debug=$1; else debug=0; fi
export TEMPFILE FILE GET64 GET32 debug
preReqs() {
  #make sure required binaries exist
  if [ $debug -gt 1 ]; then echo "DEBUG: preReqs";fi
    for file in /bin/awk /bin/egrep /bin/grep /bin/rpm /bin/sed /bin/sort /usr/bin/createrepo /usr/bin/reposync /usr/bin/wc /usr/bin/wget; do
    if [ ! -f ${file} ]; then 
      /bin/echo " ${file} not found. Cannot continue"; exit 1; 
    else 
      if [ $debug -gt 0 ]; then /bin/echo -n ".";fi; 
    fi
  done
  if [ $debug -gt 1 ]; then echo ;fi
}
preReqs
checkDirs() {
  if [ $debug -gt 1 ]; then echo ;fi
  if [ ! -d ${TOPDIR}/keys ]; then
    mkdir -p ${TOPDIR}/keys
  fi
  for KEY in VMWARE-PACKAGING-GPG-DSA-KEY.pub VMWARE-PACKAGING-GPG-RSA-KEY.pub
  do
    if [ ! -f ${TOPDIR}/keys/${KEY} ]; then
      /usr/bin/wget --quiet -O ${TOPDIR}/keys/${KEY} http://packages.vmware.com/tools/keys/${KEY}
    fi
  done
}
checkDirs
getDirList(){
  if [ $debug -gt 1 ]; then echo "DEBUG: getDirList";fi
  /usr/bin/wget -O - --quiet http://packages.vmware.com/tools/esx/index.html >${DIRLIST}
  if [ $? -eq 0 ]; then
    if [ $debug -gt 0 ]; then echo -n .;fi;
  else echo "collection of directories from packages.vmware.com/tools/esx/index.html failed. Fix!"; exit 1;
  fi
  if [ $debug -gt 1 ]; then echo ;fi
}
getDirList
parseDirList(){
  if [ $debug -gt 1 ]; then echo "DEBUG: parseDirList";fi
  /bin/cat ${DIRLIST}|/bin/awk '/HREF/ sub(/HREF=.*">/,"") sub("/</A>","") {print $5}'|/bin/egrep -v '(HTML|Parent|^$)'|/bin/sort>${VERLIST}
  if [ $? -eq 0 ]; then
    if [ $debug -gt 0 ]; then /bin/echo -n ".";fi;
  else echo "parsing available versions from ${DIRLIST} failed. Fix!"; exit 1;
  fi
  if [ $debug -gt 1 ]; then echo ;fi
}
parseDirList
checkArch(){
  if [ $debug -gt 1 ]; then echo "DEBUG: checkArch: $1 $2 $3 $4";fi
  if [ -z $1 ]; then echo "checkArch: Did not get the major version I should check for. cannot continue";exit 1; fi
  if [ -z $2 ]; then echo "checkArch: Did not get the arch I should check for. cannot continue";exit 1; fi
  if [ -z $3 ]; then echo "checkArch: Did not get the major version $1 bool. cannot continue";exit 1;fi
  if [ -z $4 ]; then echo "checkArch: Did not get the $2 bool. cannot continue";exit 1;fi
  if [ $1 -eq 5 ]; then
    MAJOR='rhel5'
  elif [ $1 -eq 6 ]; then
    MAJOR='rhel6'
  else
    echo "got unexpected value for Major version. Expecting 5 or 6, got $1. Cannot continue"; exit 1;
  fi
  if [ $2 == "i386" ] || [ $2 == "i686" ] || [ $2 == "x86_64" ]; then
    ARCH=$2
  else
    echo "got unexpected value for arch: $2 expecting i386 i686 or x86_64. Cannot continue"; exit 1;
  fi
  if [ $3 == "true" ]; then
    #we should try to parse what versions have repos for this major version
    if [ $debug -gt 2 ]; then echo "DEBUG: checkArch $1 true" ;fi
    if [ $4 == "true" ]; then
      #we should try to parse what versions have repos for this arch
      if [ $debug -gt 2 ]; then echo "DEBUG: checkArch $1 $2 true true" ;fi
      for VERSION in `/bin/cat $VERLIST`; do
      #for VERSION in latest; do
        #check to see if the file exists
        if [ $debug -gt 2 ]; then 
          echo "wget -O/dev/null -q  http://packages.vmware.com/tools/esx/${VERSION}/${MAJOR}/${ARCH}/index.html"
        fi
        /usr/bin/wget -O/dev/null -q  http://packages.vmware.com/tools/esx/${VERSION}/${MAJOR}/${ARCH}/index.html
        if [ $? -eq 0 ]; then
          #the file exists
          if   [ $debug -gt 1 ]; then echo "${VERSION}/${MAJOR}/${ARCH} exists. adding";
          elif [ $debug -gt 0 ]; then /bin/echo -n ".";
          fi
          addRepo ${MAJOR} ${ARCH} ${VERSION}
          createMirrorFiles ${MAJOR} ${ARCH} ${VERSION}
          createRepo ${MAJOR} ${ARCH} ${VERSION}
        else
          if   [ $debug -gt 1 ]; then echo "${VERSION}/${MAJOR}/${ARCH} does not exist. skipping";
          elif [ $debug -gt 0 ]; then /bin/echo -n ".";
          fi
        fi
      done
    else 
      if [ $debug -gt 1 ]; then echo "arch $ARCH fetching for $MAJOR $VERSION disabled. Skipping"; fi
    fi
  else
    if [ $debug -gt 1 ]; then echo "major version $MAJOR fetching for $VERSION disabled. Skipping"; fi
  fi
  if [ $debug -gt 1 ]; then echo ;fi
}
addRepo() {
  if [ $debug -gt 1 ]; then echo "DEBUG: addRepo: $1 $2 $3";fi
  if [ -z $1 ]; then echo "addRepo: Did not get the major version I should check for. cannot continue";exit 1;fi
  if [ -z $2 ]; then echo "addRepo: Did not get the arch I should check for. cannot continue";exit 1;fi
  if [ -z $3 ]; then echo "addRepo: Did not get the vmware version. cannot continue";exit 1;fi
  if [ $1 == "rhel5" ]; then
    RELEASE=5
  else
    RELEASE=6
  fi
  REPODIR="$TOPDIR/esx/$3/$RELEASE"
  REPOFILE="$TOPDIR/vmware.reposcratch"
  if [ $debug -gt 3 ]; then echo "DEBUG: addRepo: Creating repo file $3_${RELEASE}_$2";fi
  echo "[$2]" >$REPOFILE
  echo "name=$3_${RELEASE}_$2" >>$REPOFILE
  echo "baseurl=http://packages.vmware.com/tools/esx/${3}/${1}/${2}" >>$REPOFILE
  rm -rf /var/cache/yum/$2/
  if [ $debug -gt 1 ]; then
    /usr/bin/reposync    -n -c ${REPOFILE} -r $2 -p $REPODIR
  else
    /usr/bin/reposync -q -n -c ${REPOFILE} -r $2 -p $REPODIR
  fi
  if [ $debug -gt 0 ]; then /bin/echo -n "." ;fi
  rm -f $REPOFILE
  rm -rf /var/cache/yum/$2/
  if [ $debug -gt 0 ]; then /bin/echo -n "." ;fi
}
createMirrorFiles() {
  if [ $debug -gt 0 ]; then echo "DEBUG: createMirrorFiles $1 $2 $3";fi
  if [ -z $1 ]; then echo "createMirrorFiles: Did not get the major version I should check for. cannot continue";exit 1;fi
  if [ -z $2 ]; then echo "createMirrorFiles: Did not get the arch I should check for. cannot continue";exit 1;fi
  if [ -z $3 ]; then echo "createMirrorFiles: Did not get the vmware version. cannot continue";exit 1;fi
  if [ $1 == "rhel5" ]; then
    RELEASE=5
  else
    RELEASE=6
  fi
  MIRRORDIR="$TOPDIR/esx/$3/$RELEASE/$2"
  MIRRORFILE=$MIRRORDIR/mirrorlist
  if [ -d $MIRRORDIR ]; then
    echo "#Mirror list for VMwareTools $3 (el$RELEASE $2)" >$MIRRORFILE
    for SERVER in ${MIRRORSERVERS[@]}; do
      echo "http://${SERVER}/vendor/vmware/esx/$3/\$releasever/\$basearch/" >>$MIRRORFILE
    done
    if [ $debug -gt 1 ]; then echo "DEBUG: createMirrorFiles: creating mirrorfile $MIRRORFILE"; 
    elif [ $debug -gt 0 ]; then /bin/echo -n "."
    fi
  else
    if [ $debug -gt 1 ]; then echo "DEBUG: createMirrorFiles: not creating mirrorfile. $MIRRORDIR doesn't exist"; 
    elif [ $debug -gt 0 ]; then /bin/echo -n "."
    fi
  fi

}
createRepo(){
  if [ $debug -gt 0 ]; then echo "DEBUG: createRepo $1 $2 $3";fi
  if [ -z $1 ]; then echo "createRepo: Did not get the major version I should check for. cannot continue";exit 1;fi
  if [ -z $2 ]; then echo "createRepo: Did not get the arch I should check for. cannot continue";exit 1;fi
  if [ -z $3 ]; then echo "createRepo: Did not get the vmware version. cannot continue";exit 1;fi
  if [ $1 == "rhel5" ]; then
    RELEASE=5
  else
    RELEASE=6
  fi
  REPODIR="$TOPDIR/esx/$3/$RELEASE/$2"
  if [ -d $REPODIR ]; then
    if [ $debug -gt 1 ]; then
      createrepo -s sha -v $REPODIR
    elif [ $debug -gt 0 ]; then
      createrepo -s sha    $REPODIR
      /bin/echo -n "."
    else
      createrepo -s sha -q $REPODIR
    fi
  fi
}
cleanUp() {
  rm -f $DIRLIST $VERLIST
}
checkArch 5 i386   $GET5 $GETi386
checkArch 5 i686   $GET5 $GETi686
checkArch 5 x86_64 $GET5 $GETx86_64
checkArch 6 i386   $GET6 $GETi386 
checkArch 6 i686   $GET6 $GETi686
checkArch 6 x86_64 $GET6 $GETx86_64
cleanUp
