#!/bin/bash
###################################################################################
#This script is for use on SGE clusters only.
#Suggested resource values above should be sane and work.
#Script written by JMoore 01-07-2021 @ The University of Sheffield IT Services.
###################################################################################
#Notes:

########################  Options and version selections  #########################
###################################################################################


#Define Names and versions
PACKAGENAME=make
PACKAGEVER=4.0
GCCVER=8.2

FILENAME=$PACKAGENAME-$PACKAGEVER.tar.gz
URL="https://ftp.gnu.org/gnu/$PACKAGENAME/$FILENAME"
#   https://ftp.gnu.org/gnu/make/make-4.3.tar.gz

###################################################################################

# Signal handling for failure
handle_error () {
    errcode=$? # save the exit code as the first thing done in the trap function 
    echo "Error: $errorcode" 
    echo "Command: $BASH_COMMAND" 
    echo "Line: ${BASH_LINENO[0]}"
    exit $errcode  # or use some other value or do return instead 
}
trap handle_error ERR

#Start the main work of the script
echo "Running install script to make Package: "  $PACKAGENAME " Version: "  $PACKAGEVER 


#Setup calculated variables
INSTALLDIR=/data/$USER/installations/dev/$PACKAGENAME/$PACKAGEVER/gcc-$GCCVER/
SOURCEDIR=$INSTALLDIR/src

MODULEDIR=/$HOME/modulefiles/dev/$PACKAGENAME/$PACKAGEVER/
MODULEFILENAME=gcc-$GCCVER

FULLPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")

#Load Modules
# Not needed for binary install

echo "Loaded Modules: " $LOADEDMODULES
module load dev/gcc/$GCCVER

#Make directories
mkdir -p $INSTALLDIR
mkdir -p $SOURCEDIR

echo "Install Directory: "  $INSTALLDIR
echo "Source Directory: "  $SOURCEDIR

#Go to the source directory
cd $SOURCEDIR

#Download source and extract
echo "Download Source"


if test -f "$FILENAME"; then
    if test -d $PACKAGENAME-$PACKAGEVER; then
        rm -r $PACKAGENAME-$PACKAGEVER
    fi
        tar -xzf  $FILENAME   
else
    wget $URL
    tar -xzf  $FILENAME
fi

cd $PACKAGENAME-$PACKAGEVER

#Configure
echo "Configuring:"
mkdir build
cd build

../configure --prefix=$INSTALLDIR

#Clean
echo "Make precleaning:"

make -j $NSLOTS clean


#Make
echo "Making:"

make -j $NSLOTS


#Check
echo "Make checking:"

make -j $NSLOTS check

echo "Skipping - uncomment if desired."


#Install
echo "Make installing:"

make -j $NSLOTS install


#Echo the loaded modules used to compile the installed directory
#Splits on colon sends each element to new line
echo $LOADEDMODULES | awk 'BEGIN{RS=":"}{$1=$1}1' >> $INSTALLDIR/compiler_loaded_modules_list

#Copy the used install script to install directory
cp $FULLPATH $INSTALLDIR/install_script.sge

################################## Begin adding the module file ###################################
mkdir -p $MODULEDIR

if test -f "$MODULEDIR$MODULEFILENAME"; then
    rm $MODULEDIR$MODULEFILENAME #Remove it if it already exists due to prior failure to install.
    touch $MODULEDIR$MODULEFILENAME
else
    touch $MODULEDIR$MODULEFILENAME
fi


#Dashes need to be removed from package names or module files will break.
PACKAGENAME=${PACKAGENAME//-/_}


################################ Add the start of the module file #################################

cat <<EOF >>$MODULEDIR$MODULEFILENAME
#%Module1.0#####################################################################
##
## $PACKAGENAME $PACKAGEVER module file
##

## Module file logging
source /usr/local/etc/module_logging.tcl
##

proc ModulesHelp { } {
        puts stderr "Makes $PACKAGENAME $PACKAGEVER available"
}

module-whatis   "Makes $PACKAGENAME $PACKAGEVER available"

# Add required module loads

EOF

################################# Now add the needed module loads #################################

sed 's/.*/module load &/' $INSTALLDIR/compiler_loaded_modules_list >> $MODULEDIR$MODULEFILENAME


###################### Now add the Package root directory variable and path #######################

cat <<EOF >>$MODULEDIR$MODULEFILENAME

# Set package root directory
set ROOT_DIR_$PACKAGENAME  $INSTALLDIR

EOF

NESTEDROOTDIRVAR=\$ROOT_DIR_$PACKAGENAME

#################################### Now add the PATH if needed ###################################

if [ -d $INSTALLDIR/bin ]
then

cat <<EOF >>$MODULEDIR$MODULEFILENAME

# Set executable path
prepend-path PATH        		 $NESTEDROOTDIRVAR/bin

EOF
fi

################################# Now add the LIBRARIES if needed #################################

if [ -d $INSTALLDIR/lib ]
then

cat <<EOF >>$MODULEDIR$MODULEFILENAME

# Set library paths
prepend-path LD_LIBRARY_PATH 	 $NESTEDROOTDIRVAR/lib
prepend-path LIBRARY_PATH 	     $NESTEDROOTDIRVAR/lib

EOF
fi

if [ -d $INSTALLDIR/lib64 ]
then

cat <<EOF >>$MODULEDIR$MODULEFILENAME

# Set 64 bit library paths
prepend-path LD_LIBRARY_PATH 	 $NESTEDROOTDIRVAR/lib64
prepend-path LIBRARY_PATH 	     $NESTEDROOTDIRVAR/lib64

EOF
fi

################################# Now add the C Pathing if needed #################################

cat <<EOF >>$MODULEDIR$MODULEFILENAME

# Set CMAKE PREFIX PATH
prepend-path CMAKE_PREFIX_PATH 	 $NESTEDROOTDIRVAR

EOF

if [ -d $INSTALLDIR/include ]
then

cat <<EOF >>$MODULEDIR$MODULEFILENAME

# Set CMAKE INCLUDES
prepend-path CPLUS_INCLUDE_PATH  $NESTEDROOTDIRVAR/include
prepend-path CPATH 		         $NESTEDROOTDIRVAR/include

EOF
fi
################################# Now add the PKG_CONFIG if needed#################################

if [ -d $INSTALLDIR/lib/pkgconfig ]
then

cat <<EOF >>$MODULEDIR$MODULEFILENAME

# Set PKG_CONFIG_PATH
prepend-path PKG_CONFIG_PATH     $NESTEDROOTDIRVAR/lib/pkgconfig

EOF

fi

if [ -d $INSTALLDIR/lib64/pkgconfig ]
then

cat <<EOF >>$MODULEDIR$MODULEFILENAME

# Set 64bit PKG_CONFIG_PATH
prepend-path PKG_CONFIG_PATH     $NESTEDROOTDIRVAR/lib64/pkgconfig

EOF

fi


if [ -d $INSTALLDIR/share/pkgconfig ]
then

cat <<EOF >>$MODULEDIR$MODULEFILENAME

# Set share PKG_CONFIG_PATH
prepend-path PKG_CONFIG_PATH     $NESTEDROOTDIRVAR/share/pkgconfig

EOF

fi

################################# Now add the ACLOCAL_PATH if needed#################################
if [ -d $INSTALLDIR/share/aclocal ]
then

cat <<EOF >>$MODULEDIR$MODULEFILENAME

# Set share ACLOCAL_PATH
prepend-path ACLOCAL_PATH     $NESTEDROOTDIRVAR/share/aclocal

EOF

fi


#################################  Custom ENV VARs in module needed  #################################
cat <<EOF >>$MODULEDIR$MODULEFILENAME

EOF

################################# Now chmod the directories properly #################################

chown $USER:hpc_app-admins $INSTALLDIR
chmod 775 -R $INSTALLDIR
chown $USER:hpc_app-admins $MODULEDIR$MODULEFILENAME
chmod 775 $MODULEDIR$MODULEFILENAME

ELOG=${SGE_O_WORKDIR}/${JOB_NAME}.e${JOB_ID}
OLOG=${SGE_O_WORKDIR}/${JOB_NAME}.o${JOB_ID}

if test -f "$ELOG"; then
    echo "$ELOG exists. Copying to install dir."
    cp $ELOG $INSTALLDIR
fi

if test -f "$OLOG"; then
    echo "$OLOG exists. Copying to install dir."
    cp $OLOG $INSTALLDIR
fi

#Symlink make to gmake
ln -s $INSTALLDIR/bin/make $INSTALLDIR/bin/gmake
