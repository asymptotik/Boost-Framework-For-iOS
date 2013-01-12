#===============================================================================
# Filename:  boost.sh
# Author:    Based on the good work of Pete Goodliffe updated by Rick Boykin
#
# Copyright: (c) Copyright 2009 Pete Goodliffe
# Licence:   Please feel free to use this, with attribution
#===============================================================================
# 
# Downloads and Builds a Boost framework for the iPhone.
# Creates a set of universal libraries that can be used on an iPhone and in the
# iPhone simulator. Then creates a pseudo-framework to make using boost in Xcode
# less painful.
#
# To configure the script, define:
#    BOOST_LIBS:        which libraries to build
#    BOOST_VERSION:     version number of the boost library (e.g. 1_51_0)
#    IPHONE_SDKVERSION: iPhone SDK version (e.g. 5.1)
#
# Then go get the source tar.bz of the boost you want to build, shove it in the
# same directory as this script, and run "./boost.sh". Grab a cuppa. And voila.
#===============================================================================

#    - chrono                   : not building
#    - context                  : not building
#    - date_time                : building
#    - exception                : not building
#    - filesystem               : building
#    - graph                    : not building
#    - graph_parallel           : not building
#    - iostreams                : not building
#    - locale                   : not building
#    - math                     : not building
#    - mpi                      : not building
#    - program_options          : building
#    - python                   : not building
#    - random                   : building
#    - regex                    : building
#    - serialization            : not building
#    - signals                  : building
#    - system                   : building
#    - test                     : not building
#    - thread                   : building
#    - timer                    : not building
#    - wave                     : not building

: ${BOOST_VERSION:=1_51_0}
: ${BOOST_LIBS:="thread signals filesystem regex program_options system date_time serialization exception random"}
: ${IPHONE_SDKVERSION:=6.0}
: ${XCODE_ROOT:=`xcode-select -print-path`}
: ${EXTRA_CPPFLAGS:="-DBOOST_AC_USE_PTHREADS -DBOOST_SP_USE_PTHREADS -stdlib=libc++ -std=gnu++11"}

# The EXTRA_CPPFLAGS definition works around a thread race issue in
# shared_ptr. I encountered this historically and have not verified that
# the fix is no longer required. Without using the posix thread primitives
# an invalid compare-and-swap ARM instruction (non-thread-safe) was used for the
# shared_ptr use count causing nasty and subtle bugs.
#
# Should perhaps also consider/use instead: -BOOST_SP_USE_PTHREADS

: ${TARBALLDIR:=`pwd`}
: ${SRCDIR:=`pwd`}
: ${BUILDDIR:=`pwd`/ios/build}
: ${PREFIXDIR:=`pwd`/ios/prefix}
: ${FRAMEWORKDIR:=`pwd`/ios/framework}
: ${COMPILER:="clang++"}

BOOST_TARBALL=$TARBALLDIR/boost_$BOOST_VERSION.tar.bz2
BOOST_SRC=$SRCDIR/boost_${BOOST_VERSION}
BOOST_URL=http://sourceforge.net/projects/boost/files/boost/1.51.0/boost_1_51_0.tar.bz2

#===============================================================================

ARM_DEV_DIR=$XCODE_ROOT/Platforms/iPhoneOS.platform/Developer/usr/bin/
SIM_DEV_DIR=$XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer/usr/bin/

ARM_COMBINED_LIB=$BUILDDIR/lib_boost_arm.a
SIM_COMBINED_LIB=$BUILDDIR/lib_boost_x86.a

#===============================================================================

echo "BOOST_VERSION:     $BOOST_VERSION"
echo "BOOST_LIBS:        $BOOST_LIBS"
echo "BOOST_TARBALL:     $BOOST_TARBALL"
echo "BOOST_SRC:         $BOOST_SRC"
echo "BUILDDIR:          $BUILDDIR"
echo "PREFIXDIR:         $PREFIXDIR"
echo "FRAMEWORKDIR:      $FRAMEWORKDIR"
echo "IPHONE_SDKVERSION: $IPHONE_SDKVERSION"
echo "XCODE_ROOT:        $XCODE_ROOT"
echo "COMPILER:          $COMPILER"
echo

#===============================================================================
# Functions
#===============================================================================

abort()
{
    echo
    echo "Aborted: $@"
    exit 1
}

doneSection()
{
    echo
    echo "    ================================================================="
    echo "    Done"
    echo
}

#===============================================================================

cleanEverything()
{
    echo Cleaning everything before we start to build...
    rm -rf $BOOST_SRC
    rm -rf $BUILDDIR
    rm -rf $PREFIXDIR
    rm -rf $FRAMEWORKDIR/$FRAMEWORK_NAME.framework
    doneSection
}

#===============================================================================
fetchSource()
{
    if [ ! -e $BOOST_TARBALL ]; then
	echo "Fetching $BOOST_URL ..."
	curl -L -o $BOOST_TARBALL $BOOST_URL
    fi
}

#===============================================================================
unpackSource()
{
    echo Unpacking boost into $SRCDIR...
    
    [ -d $SRCDIR ]    || mkdir -p $SRCDIR
    [ -d $BOOST_SRC ] || ( cd $SRCDIR; tar xfj $BOOST_TARBALL )
    [ -d $BOOST_SRC ] && echo "    ...unpacked as $BOOST_SRC"
    [ -f ${SRCDIR}/darwin.jam_${BOOST_VERSION} ] && ( cp $SRCDIR/darwin.jam_${BOOST_VERSION} ${BOOST_SRC}/tools/build/v2/tools/darwin.jam ) && echo "Updated darwin.jam"
    doneSection
}

#===============================================================================

resetUserConfig()
{
    USER_CONFIG="$BOOST_SRC/tools/build/v2/user-config.jam"
    # Get line number of the first line starting with "using darwin"
    lineNum=$(grep -n -m 1 --regexp='# DELETE HERE XXXXXX' $USER_CONFIG)
    lineNum=${lineNum%":"*}
    if [[ "$lineNum" ]]; then
        echo "Cleaning $USER_CONFIG"
        lineNum=$(expr $lineNum - 1)
        # Use sed to delete the end of the file that we may have written to previously
        echo -n -e "$(sed -n '1,'$lineNum'p' $USER_CONFIG)" > $USER_CONFIG
    fi
}

writeBjamUserConfig()
{
    resetUserConfig
    # You need to do this to point bjam at the right compiler
    # ONLY SEEMS TO WORK IN HOME DIR GRR
    echo Writing usr-config
    #mkdir -p $BUILDDIR
    #cat > ~/user-config.jam <<EOF
    cat >> $BOOST_SRC/tools/build/v2/user-config.jam <<EOF
# DELETE HERE XXXXXX
using darwin : ${IPHONE_SDKVERSION}~iphone
   : $XCODE_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/bin/$COMPILER -arch armv7 -arch armv7s -fvisibility=hidden -fvisibility-inlines-hidden $EXTRA_CPPFLAGS
   : <striper>
   : <architecture>arm <target-os>iphone
   ;
using darwin : ${IPHONE_SDKVERSION}~iphonesim
   : $XCODE_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/bin/$COMPILER -arch i386 -fvisibility=hidden -fvisibility-inlines-hidden $EXTRA_CPPFLAGS
   : <striper>
   : <architecture>x86 <target-os>iphone
   ;
EOF
    doneSection
}

#===============================================================================

inventMissingHeaders()
{
    # These files are missing in the ARM iPhoneOS SDK, but they are in the simulator.
    # They are supported on the device, so we copy them from x86 SDK to a staging area
    # to use them on ARM, too.
    echo Invent missing headers
    echo "cp $XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator${IPHONE_SDKVERSION}.sdk/usr/include/{crt_externs,bzlib}.h $BOOST_SRC"
    cp $XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator${IPHONE_SDKVERSION}.sdk/usr/include/{crt_externs,bzlib}.h $BOOST_SRC
}

#===============================================================================

bootstrapBoost()
{
    cd $BOOST_SRC
    BOOST_LIBS_COMMA=$(echo $BOOST_LIBS | sed -e "s/ /,/g")
    echo "Bootstrapping (with libs $BOOST_LIBS_COMMA)"
    ./bootstrap.sh --with-libraries=$BOOST_LIBS_COMMA
    doneSection
}

#===============================================================================

buildBoostForiPhoneOS()
{
    cd $BOOST_SRC
    
    ./bjam --prefix="$PREFIXDIR" toolset=darwin architecture=arm target-os=iphone macosx-version=iphone-${IPHONE_SDKVERSION} define=_LITTLE_ENDIAN link=static install
    doneSection

    ./bjam toolset=darwin architecture=x86 target-os=iphone macosx-version=iphonesim-${IPHONE_SDKVERSION} link=static stage
    doneSection
}

#===============================================================================

# $1: Name of a boost library to lipoficate (technical term)
lipoficate()
{
    : ${1:?}
    NAME=$1
    echo liboficate: $1
    ARM=$BOOST_SRC/bin.v2/libs/$NAME/build/darwin-${IPHONE_SDKVERSION}~iphone/release/architecture-arm/link-static/macosx-version-iphone-$IPHONE_SDKVERSION/target-os-iphone/threading-multi/libboost_$NAME.a
    I386=$BOOST_SRC/bin.v2/libs/$NAME/build/darwin-${IPHONE_SDKVERSION}~iphonesim/release/architecture-x86/link-static/macosx-version-iphonesim-$IPHONE_SDKVERSION/target-os-iphone/threading-multi/libboost_$NAME.a

    mkdir -p $PREFIXDIR/lib
    xcrun -sdk iphoneos lipo \
        -create \
        "$ARM" \
        "$I386" \
        -o          "$PREFIXDIR/lib/libboost_$NAME.a" \
    || abort "Lipo $1 failed"
}

# This creates universal versions of each individual boost library
lipoAllBoostLibraries()
{
    for i in $BOOST_LIBS; do lipoficate $i; done;

    doneSection
}

unpackArchive()
{
    ARCH=$1
    NAME=$2

    echo "Unpacking $NAME"

    mkdir -p $BUILDDIR/$ARCH/obj/$NAME
    rm $BUILDDIR/$ARCH/obj/$NAME/*.o
    rm $BUILDDIR/$ARCH/obj/$NAME/*.SYMDEF*

    (
	cd $BUILDDIR/$ARCH/obj/$NAME;  ar -x ../../libboost_$NAME.a;
	for FILE in *.o; do
	    NEW_FILE="${NAME}_${FILE}"
	    mv $FILE $NEW_FILE
	done
    );
}

scrunchAllLibsTogetherInOneLibPerPlatform()
{
    ALL_LIBS_ARM=""
    ALL_LIBS_SIM=""
    for NAME in $BOOST_LIBS; do
        ALL_LIBS_ARM="$ALL_LIBS_ARM $BOOST_SRC/bin.v2/libs/$NAME/build/darwin-${IPHONE_SDKVERSION}~iphone/release/architecture-arm/link-static/macosx-version-iphone-$IPHONE_SDKVERSION/target-os-iphone/threading-multi/libboost_$NAME.a";
        ALL_LIBS_SIM="$ALL_LIBS_SIM $BOOST_SRC/bin.v2/libs/$NAME/build/darwin-${IPHONE_SDKVERSION}~iphonesim/release/architecture-x86/link-static/macosx-version-iphonesim-$IPHONE_SDKVERSION/target-os-iphone/threading-multi/libboost_$NAME.a";
    done;

    mkdir -p $BUILDDIR/armv7
    mkdir -p $BUILDDIR/armv7s
    mkdir -p $BUILDDIR/i386

    echo Splitting all existing fat binaries...
    for NAME in $BOOST_LIBS; do
        ALL_LIBS="$ALL_LIBS libboost_$NAME.a"
        xcrun -sdk iphoneos lipo "$BOOST_SRC/bin.v2/libs/$NAME/build/darwin-${IPHONE_SDKVERSION}~iphone/release/architecture-arm/link-static/macosx-version-iphone-$IPHONE_SDKVERSION/target-os-iphone/threading-multi/libboost_$NAME.a" -thin armv7 -o $BUILDDIR/armv7/libboost_$NAME.a
        xcrun -sdk iphoneos lipo "$BOOST_SRC/bin.v2/libs/$NAME/build/darwin-${IPHONE_SDKVERSION}~iphone/release/architecture-arm/link-static/macosx-version-iphone-$IPHONE_SDKVERSION/target-os-iphone/threading-multi/libboost_$NAME.a" -thin armv7s -o $BUILDDIR/armv7s/libboost_$NAME.a
        cp "$BOOST_SRC/bin.v2/libs/$NAME/build/darwin-${IPHONE_SDKVERSION}~iphonesim/release/architecture-x86/link-static/macosx-version-iphonesim-$IPHONE_SDKVERSION/target-os-iphone/threading-multi/libboost_$NAME.a" $BUILDDIR/i386/
    done

    echo "Decomposing each architecture's .a files"
    for NAME in $BOOST_LIBS; do
        echo "Decomposing libboost_${NAME}.a..."
	unpackArchive "armv7" $NAME
	unpackArchive "armv7s" $NAME
	unpackArchive "i386" $NAME
    done

    echo "Linking each architecture into an uberlib ($ALL_LIBS => libboost.a )"
    ls $BUILDDIR/*
    rm $BUILDDIR/*/libboost.a

    for NAME in $BOOST_LIBS; do
	echo ...armv7
	(cd $BUILDDIR/armv7; $ARM_DEV_DIR/ar crus libboost.a obj/$NAME/*.o; )
	echo ...armv7s
	(cd $BUILDDIR/armv7s; $ARM_DEV_DIR/ar crus libboost.a obj/$NAME/*.o; )
	echo ...i386
	(cd $BUILDDIR/i386;  $SIM_DEV_DIR/ar crus libboost.a obj/$NAME/*.o; )
    done
}

#===============================================================================

                    VERSION_TYPE=Alpha
                  FRAMEWORK_NAME=boost
               FRAMEWORK_VERSION=A

       FRAMEWORK_CURRENT_VERSION=$BOOST_VERSION
 FRAMEWORK_COMPATIBILITY_VERSION=$BOOST_VERSION

buildFramework()
{
    FRAMEWORK_BUNDLE=$FRAMEWORKDIR/$FRAMEWORK_NAME.framework

    rm -rf $FRAMEWORK_BUNDLE

    echo "Framework: Setting up directories..."
    mkdir -p $FRAMEWORK_BUNDLE
    mkdir -p $FRAMEWORK_BUNDLE/Versions
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Resources
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Headers
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Documentation

    echo "Framework: Creating symlinks..."
    ln -s $FRAMEWORK_VERSION               $FRAMEWORK_BUNDLE/Versions/Current
    ln -s Versions/Current/Headers         $FRAMEWORK_BUNDLE/Headers
    ln -s Versions/Current/Resources       $FRAMEWORK_BUNDLE/Resources
    ln -s Versions/Current/Documentation   $FRAMEWORK_BUNDLE/Documentation
    ln -s Versions/Current/$FRAMEWORK_NAME $FRAMEWORK_BUNDLE/$FRAMEWORK_NAME

    FRAMEWORK_INSTALL_NAME=$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/$FRAMEWORK_NAME

    echo "Lipoing library into $FRAMEWORK_INSTALL_NAME..."
    xcrun -sdk iphoneos lipo \
        -create \
        -arch armv7 "$BUILDDIR/armv7/libboost.a" \
        -arch armv7s "$BUILDDIR/armv7s/libboost.a" \
        -arch i386  "$BUILDDIR/i386/libboost.a" \
        -o          "$BUILDDIR/libboost.a" \
    || abort "Lipo $1 failed"

    cp "$BUILDDIR/libboost.a" "$FRAMEWORK_INSTALL_NAME"
    echo "Framework: Copying includes..."
    cp -r $PREFIXDIR/include/boost/*  $FRAMEWORK_BUNDLE/Headers/

    echo "Framework: Creating plist..."
    cat > $FRAMEWORK_BUNDLE/Resources/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleExecutable</key>
	<string>${FRAMEWORK_NAME}</string>
	<key>CFBundleIdentifier</key>
	<string>org.boost</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>${FRAMEWORK_CURRENT_VERSION}</string>
</dict>
</plist>
EOF
    doneSection
}

#===============================================================================
# Execution starts here
#===============================================================================

mkdir -p $BUILDDIR

case $BOOST_VERSION in
    1_51_0 )
        cleanEverything
	fetchSource
        unpackSource
        inventMissingHeaders
        writeBjamUserConfig
        bootstrapBoost
        buildBoostForiPhoneOS
        scrunchAllLibsTogetherInOneLibPerPlatform
        lipoAllBoostLibraries
        buildFramework
        ;;
    default )
        echo "This version ($BOOST_VERSION) is not supported"
        ;;
esac

echo "Completed successfully"

#===============================================================================
