#!/bin/bash

# HLstatsX Community Edition - Real-time player and clan rankings and statistics
# http://www.hlxcommunity.com
# Copyleft (L) 2008-20XX Nicholas Hastings (nshastings@gmail.com)
# 
# HLstatsX is an enhanced version of ELstatsNEO
# ELstatsNEO - Real-time player and clan rankings and statistics
# http://ovrsized.neo-soft.org/
# Copyleft (L) 2008-20XX Malte Bayer (steam@neo-soft.org)
# 
# ELstatsNEO is an very improved & enhanced - so called Ultra-Humongus Edition of HLstatsX
# HLstatsX - Real-time player and clan rankings and statistics for Half-Life 2
# http://www.hlstatsx.com/
# Copyright (C) 2005-2007 Tobias Oetzel (Tobi@hlstatsx.com)
#
# HLstatsX is an enhanced version of HLstats made by Simon Garner
# HLstats - Real-time player and clan rankings and statistics for Half-Life
# http://sourceforge.net/projects/hlstats/
# Copyright (C) 2001  Simon Garner
#             
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
# 
# For support and installation notes visit http://ovrsized.neo-soft.org!

# This is the build-bot script for the HLX:CE project.
# This script has been created to work with the Mercurial Version Control System.

# Please be sure to configure the appropriate settings below!

# Location of the development repository
SRC_DEV=/home/hg/repository/hlxce/hlx-dev

# Location to output development builds
OUTPUT_DEV=/home/hg/hlx_buildbot/output/development

# Location of the stable repository
SRC_STABLE=/home/hg/repository/hlxce/hlx-16

# Location to output stable builds
OUTPUT_STABLE=/home/hg/hlx_buildbot/output/stable

# Temporary build location
BUILD_LOCATION=/tmp/hlxce-build-snapshot

# Package Prefix
# Example: HLXCommunityEdition
PKG_PREFIX=HLXCE-snapshot-

# Configure the absolute path to the Sourcemod Scripting folder
# Used to compile sourcemod plugins (when applicable)
SOURCEMOD_DIR=/home/hg/utilities/sourcemod/addons/sourcemod/scripting

# Configure the absolute path to the AMXmodX Scripting folder
# Used to compile AMX plugins
AMXMODX_DIR=/home/hg/utilities/amxmodx/addons/amxmodx/scripting

# Configure where to store the incremental snapshot counter
COUNTER_FILE=/home/hg/hlx_buildbot/snapshot_counter

# NOTHING TO CHANGE BELOW THIS LINE
# -----------------------------------------------------------------------------

# Get the current directory
CURRENT_DIR=`pwd`

# Load the last snapshot counter used if needed
if [ -f ${COUNTER_FILE} ]; then
	SNAPSHOT_COUNTER=`cat ${COUNTER_FILE}`
else
	SNAPSHOT_COUNTER=1
	echo 1 > ${COUNTER_FILE}
fi

# Set our build folder variable
BUILD_FOLDER=${PKG_PREFIX}${SNAPSHOT_COUNTER}


# Determine which branch (or both) to build

# This section needs to be configured after talking with the duck
# Basically need to set BUILD_DEV = 0 or 1 and BUILD_STABLE = 0 or 1, and that will determine what needs to get built.

BUILD_DEV=$1
BUILD_STABLE=$2

# Build development snapshot, if necessary.
if [ ${BUILD_DEV} == 1 ]; then

	echo -ne "[+] Development Package: A request to build a new development package was received.\\n    Building snapshot #${SNAPSHOT_COUNTER}\\n\\n"

	# Call hg to update the local development repository
	echo -ne "[+] Updating local development repository\\n"
	cd ${SRC_DEV}
	/usr/bin/hg pull > /dev/null
	/usr/bin/hg update -C > /dev/null

	# Prepare build location
	/usr/bin/hg archive ${BUILD_LOCATION}/${BUILD_FOLDER}
	cd ${BUILD_LOCATION}/${BUILD_FOLDER}
	
	# Remove directories that should not be in the shipped packages
	echo -ne "[+] Removing unneeded/unshipable files and folders\\n"
	
	rm -Rf build
	rm -Rf extras
	rm -Rf scripts/DONOTSHIP
	find heatmaps/src/* -type d -exec rm -Rf {} \; &> /dev/null


	# Set additional permissions on folders
	echo -ne "[+] Setting permissions on hlstatsimg/games directory\\n"
	find web/hlstatsimg/games/ -type d -exec chmod 777 {} \; &> /dev/null

	# Symlink the HLXCE plugins and compile
	echo -ne "[+] Setting up symlinks for HLXCE plugin compile\\n\\n"
	ln -fs ${BUILD_LOCATION}/${BUILD_FOLDER}/sourcemod/scripting/*.sp ${SOURCEMOD_DIR}/ &> /dev/null
	ln -fs ${BUILD_LOCATION}/${BUILD_FOLDER}/sourcemod/scripting/include/*.inc ${SOURCEMOD_DIR}/include/ &> /dev/null
	ln -fs ${BUILD_LOCATION}/${BUILD_FOLDER}/amxmodx/scripting/*.sma ${AMXMODX_DIR}/ &> /dev/null
	mkdir sourcemod/plugins &> /dev/null
	mkdir amxmodx/plugins &> /dev/null

	echo -ne "[+] Compiling SourceMod Plugin\\n"
	cd ${SOURCEMOD_DIR}
	for sm_source in hlstats*.sp
	do
			smxfile="`echo ${sm_source} | sed -e 's/\.sp$/.smx/'`"
			./spcomp ${sm_source} -o${BUILD_LOCATION}/${BUILD_FOLDER}/sourcemod/plugins/${smxfile} | grep -q Error
			if [ $? = 0 ]; then
					echo " [!] WARNING: ${smxfile} DID NOT COMPILE SUCCESSFULLY."
					exit
			else
					echo " [+] ${smxfile} compiled successfully."
			fi
	done
	echo -ne "[+] SourceMod plugins compiled \\n\\n"
	
	# Do some cleanup
	cd ${BUILD_LOCATION}/${BUILD_FOLDER}/sourcemod/scripting
	find *.sp -type f -exec rm ${SOURCEMOD_DIR}/{} \;
	cd include
	find *.inc -type f -exec rm ${SOURCEMOD_DIR}/include/{} \;	
	
	echo -ne "[+] Compiling AMXMODX plugins\\n"
	cd ${AMXMODX_DIR}
	for amx_source in hlstatsx_*.sma
	do
			amxxfile="`echo ${amx_source} | sed -e 's/\.sma$/.amxx/'`"
			./amxxpc ${amx_source} -o${BUILD_LOCATION}/${BUILD_FOLDER}/amxmodx/plugins/${amxxfile} | grep -q Done
			if [ $? -eq 0 ]; then
					echo " [+] ${amxxfile} compiled successfully"
			else
					echo " [!] WARNING: ${amxxfile} DID NOT COMPILE SUCCESSFULLY."
					exit
			fi
	done
	echo -ne "[+] AMXMODX plugins compiled \\n\\n"

	# Do some cleanup
	cd ${BUILD_LOCATION}/${BUILD_FOLDER}/amxmodx/scripting
	find *.sma -type f -exec rm ${AMXMODX_DIR}/{} \;		
	
	# Build shipping packages
	echo -ne "[+] Creating compressed development packages (#${SNAPSHOT_COUNTER})\\n"
	cd ${BUILD_LOCATION}
	echo -ne " [+] Creating TGZ package\\n"
	tar --owner=0 --group=users -czf ${OUTPUT_DEV}/${PKG_PREFIX}${SNAPSHOT_COUNTER}.tar.gz ${BUILD_FOLDER}
	echo -ne " [+] Creating ZIP package\\n"
	cd ${BUILD_FOLDER}
	zip -r ${OUTPUT_DEV}/${PKG_PREFIX}${SNAPSHOT_COUNTER}.zip * > /dev/null
	echo -ne "[+] Packages created\\n"
	ln -fs ${PKG_PREFIX}${SNAPSHOT_COUNTER}.tar.gz ${OUTPUT_STABLE}/${PKG_PREFIX}latest.tar.gz
	ln -fs ${PKG_PREFIX}${SNAPSHOT_COUNTER}.zip ${OUTPUT_STABLE}/${PKG_PREFIX}latest.zip
	echo -ne "[+] Updated latest symlinks\\n\\n"

	echo -ne "[+] Cleaning up old packages\\n\\n"
	cd ${OUTPUT_DEV}
	rm -f `ls -t | tail -n +11`

	echo -ne "[+] Build for #${SNAPSHOT_COUNTER} complete.\\n\\n\\n"
	
	# Cleanup build package
	rm -Rf ${BUILD_LOCATION}/${BUILD_FOLDER}
	SNAPSHOT_COUNTER=$((SNAPSHOT_COUNTER+1))
fi

# Build stable snapshot if necessary
if [ ${BUILD_STABLE} == 1 ]; then

	echo -ne "[+] Stable Package: A request to build a new stable package was received.\\n    Building snapshot #${SNAPSHOT_COUNTER}\\n\\n"

	# Call hg to update the local stable repository
	echo -ne "[+] Updating local stable repository\\n"
	cd ${SRC_STABLE}
	/usr/bin/hg pull > /dev/null
	/usr/bin/hg update -C > /dev/null

	# Prepare build location
	/usr/bin/hg archive ${BUILD_LOCATION}/${BUILD_FOLDER}
	cd ${BUILD_LOCATION}/${BUILD_FOLDER}
	
	# Remove directories that should not be in the shipped packages
	echo -ne "[+] Removing unneeded/unshipable files and folders\\n"
	
	rm -Rf build
	rm -Rf extras
	rm -Rf scripts/DONOTSHIP
	find heatmaps/src/* -type d -exec rm -Rf {} \; &> /dev/null


	# Set additional permissions on folders
	echo -ne "[+] Setting permissions on hlstatsimg/games directory\\n"
	find web/hlstatsimg/games/ -type d -exec chmod 777 {} \; &> /dev/null

	# Symlink the source code for SourceMod and AMXModX plugins
	echo -ne "[+] Setting up symlinks for HLXCE plugin compile\\n\\n"
	ln -fs ${BUILD_LOCATION}/${BUILD_FOLDER}/sourcemod/scripting/*.sp ${SOURCEMOD_DIR}/ &> /dev/null
	ln -fs ${BUILD_LOCATION}/${BUILD_FOLDER}/sourcemod/scripting/include/*.inc ${SOURCEMOD_DIR}/include/ &> /dev/null
	ln -fs ${BUILD_LOCATION}/${BUILD_FOLDER}/amxmodx/scripting/*.sma ${AMXMODX_DIR}/ &> /dev/null
	mkdir sourcemod/plugins &> /dev/null
	mkdir amxmodx/plugins &> /dev/null

	# Compile the SourceMod plugin
	echo -ne "[+] Compiling SourceMod Plugins\\n"
	cd ${SOURCEMOD_DIR}
	for sm_source in hlstats*.sp
	do
			smxfile="`echo ${sm_source} | sed -e 's/\.sp$/.smx/'`"
			./spcomp ${sm_source} -o${BUILD_LOCATION}/${BUILD_FOLDER}/sourcemod/plugins/${smxfile} | grep -q Error
			if [ $? = 0 ]; then
					echo " [!] WARNING: ${smxfile} DID NOT COMPILE SUCCESSFULLY."
					exit
			else
					echo " [+] ${smxfile} compiled successfully."
			fi
	done
	echo -ne "[+] SourceMod plugins compiled \\n\\n"
	# Do some cleanup
	cd ${BUILD_LOCATION}/${BUILD_FOLDER}/sourcemod/scripting
	find *.sp -type f -exec rm ${SOURCEMOD_DIR}/{} \;
	cd include
	find *.inc -type f -exec rm ${SOURCEMOD_DIR}/include/{} \;		

	# Compile the AMXModX Plugin
	echo -ne "[+] Compiling AMXMODX plugins"
	cd ${AMXMODX_DIR}
	for amx_source in hlstatsx_*.sma
	do
			amxxfile="`echo ${amx_source} | sed -e 's/\.sma$/.amxx/'`"
			./amxxpc ${amx_source} -o${BUILD_LOCATION}/${BUILD_FOLDER}/amxmodx/plugins/${amxxfile} | grep -q Done
			if [ $? -eq 0 ]; then
					echo " [+] ${amxxfile} compiled successfully"
			else
					echo " [!] WARNING: ${amxxfile} DID NOT COMPILE SUCCESSFULLY."
					exit
			fi
	done
	echo -ne "[+] AMXMODX plugins compiled \\n\\n"
	# Do some cleanup
	cd ${BUILD_LOCATION}/${BUILD_FOLDER}/amxmodx/scripting
	find *.sma -type f -exec rm ${AMXMODX_DIR}/{} \;		

	# Build shipping packages
	cd ${BUILD_LOCATION}
	echo -ne "[+] Creating compressed stable packages (#${SNAPSHOT_COUNTER})\\n"
	echo -ne " [+] Creating TGZ package\\n"
	tar --owner=0 --group=users -czf ${OUTPUT_STABLE}/${PKG_PREFIX}${SNAPSHOT_COUNTER}.tar.gz ${BUILD_FOLDER}
	echo -ne " [+] Creating ZIP package\\n"
	cd ${BUILD_FOLDER}
	zip -r ${OUTPUT_STABLE}/${PKG_PREFIX}${SNAPSHOT_COUNTER}.zip * > /dev/null
	echo -ne "[+] Packages created\\n"
	ln -fs ${PKG_PREFIX}${SNAPSHOT_COUNTER}.tar.gz ${OUTPUT_STABLE}/${PKG_PREFIX}latest.tar.gz
	ln -fs ${PKG_PREFIX}${SNAPSHOT_COUNTER}.zip ${OUTPUT_STABLE}/${PKG_PREFIX}latest.zip
	echo -ne "[+] Updated latest symlinks\\n\\n"

	echo -ne "[+] Cleaning up old packages\\n\\n"
    cd ${OUTPUT_STABLE}
    rm -f `ls -t | tail -n +11`
	cd ${BUILD_FOLDER}
	rm -Rf ${BUILD_LOCATION}/${$BUILD_FOLDER}
	echo -ne "[+] Build for #${SNAPSHOT_COUNTER} complete.\\n"
	SNAPSHOT_COUNTER=$((SNAPSHOT_COUNTER+0001))
fi

# Update our build-bot snapshot counter
echo ${SNAPSHOT_COUNTER} > ${COUNTER_FILE}
exit 0
