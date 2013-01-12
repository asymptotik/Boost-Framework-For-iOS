================================================================================
 Filename:      Boost On iOS
 Author:        Rick Boykin based on the work of Pete Goodliffe
                www.goodliffe.net goodliffe.blogspot.com
 Copyright:     (c) Copyright 2009 Pete Goodliffe
 Licence:       Please feel free to use this, with attribution
================================================================================

Builds a Boost framework for the iPhone.

Creates a set of universal libraries that can be used on an iPhone and in the
iPhone simulator. Then creates a pseudo-framework to make using boost in Xcode
less painful.

Updates:

This has been updated to produce libs for armv7 and armv7s. A few issues in the
original script have been addressed. 

The script will now download boost_1.51.0 for you. This allows me to include this script in 
source control with minimal size. In the original script user_config.jam
was blindiny appended to. the script has been updated to edit the scripr rather
than update it. It uses a known comment to specify where to edit it. This allows
the script to be run multiple times without fail on an alread unpacked boost
source folder. There were also some issues with how the final fat file was generated.
Boost contains a few places where the same name was used for a file. This caused
issues because the resulting object file (.o) would end up overwriting that of
and existing (.o) file when repackaging all the separate boost libraries into
a single archive (.a). The solution used is to simply rename all the .o files
by prefixing them the package name before aggregating them into a single archive.
So far this works with boost 1.51.0 under Xcode 4.3 and greater.

There is a patch for boost 1.51.0 for Xcode 4.3 and greater. This is for 
${BOOST_SRC}/tools/build/v2/tools/darwin.jam. This distribution may contain
a replacement for that file (darwin.jam_${BOOST_VERSION}) if that file exists
the script will replace the boost version with the patched version. If not,
you will need to patch yourself. The patch can be found at:

https://svn.boost.org/trac/boost/ticket/6686

This will need to be applied MANUALLY if you are not using boost 1_51_0
================================================================================
How to use
================================================================================

To use:
- Edit the build.sh script to fit your needs.
- Run bash build.sh (configuration options are at the top of the script)
- Compiled boost is written to the ios directory

