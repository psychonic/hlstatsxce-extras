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

# Package Prefix
# Example: HLXCommunityEdition
PKG_PREFIX=HLXCommunityEdition

# Configure these to the absolute paths of the SVN trunk local copy
# and the directory were we should package the release.
TRUNK_DIR=/home/repos/hlxce/trunk
RELEASE_DIR=/home/repos/hlxce/release

# Configure the absolute path to the Sourcemod Scripting folder
# Used to compile hlstats.sp
SOURCEMOD_DIR=/home/repos/sourcemod/addons/sourcemod/scripting

# Configure the absolute path to the AMXmodX Scripting folder
# Used to compile AMX plugins
AMXMODX_DIR=/home/repos/amxmodx/addons/amxmodx/scripting

# Configure where to save completed packages
OUTPUT_DIR=`pwd`

# NOTHING TO CHANGE BELOW THIS LINE
# -----------------------------------------------------------------------------

# Get the current directory
CURRENT_DIR=`pwd`

# Divider is used to seperate sections
DIVIDER="==================================================================================================="

# clear the screen
clear

# Print Welcome message (AKA WHALE!)
cat <<YURASMACKHEAD

#     # #       #     #   #    #####  ####### 
#     # #        #   #    #   #     # #       
#     # #         # #     #   #       #       
####### #          #      #   #       #####   
#     # #         # #     #   #       #       
#     # #        #   #    #   #     # #       
#     # ####### #     #   #    #####  ####### 

${DIVIDER}

YURASMACKHEAD


# Check user input

if [ "$1" == "" ]; then
	cat <<ENDINSTRUCTIONS
package.sh usage

package.sh is used by the HLX:CE development team to prepare releases in a consistent fashion.
This script, with only the version number, will only generate FULL packages.
If you want an upgrade package enter the starting rev number
and the appropriate UPGRADE package will be created.
NOTE: This script will also grab the necessary components for the upgrader to work properly.

arguments:
#1 - version number to package (required)
#2 - revision number to start at (optional)

ENDINSTRUCTIONS
	exit
else
	VERSION=$1
fi

# Perform an SVN update on the trunk dir
echo -ne "[+] Verifing trunk is up to date.\\n\\n"
svn up ${TRUNK_DIR} > /dev/null

# Check if there's already a release directory -- if so elliminate it.
if [ -d ${RELEASE_DIR} ]; then
	rm -Rf ${RELEASE_DIR}
fi

# Remove any old packages to avoid confusion
rm -f ${OUTPUT_DIR}/${PKG_PREFIX}*

# Export current trunk to the release directory
echo -ne "[+] Exporting trunk (${TRUNK_DIR}) SVN to ${RELEASE_DIR}"
svn export ${TRUNK_DIR} ${RELEASE_DIR} > /dev/null

# Check release files for appropriate version numbers
grep "'version', '${VERSION}'" ${RELEASE_DIR}/sql/install.sql -q
if [ $? -ne 0 ]; then
	echo -ne "\\n\\n${DIVIDER}\\n\\n [!] WARNING: Install.sql does not match the build version number of ${VERSION}.\n"
	echo -ne "     Is this correct?\\n\\n${DIVIDER}"
	sleep 10
fi

cat ${RELEASE_DIR}/web/updater/*.php | grep "'${VERSION}' * 'version'" -q
if [ $? -ne 0 ]; then
	echo -ne "\\n\\n${DIVIDER}\\n\\n [!] WARNING: Could not locate an updater file that updates the version to ${VERSION}.\n"
	echo -ne "     Is this correct?\\n\\n${DIVIDER}"
	sleep 5
fi
# Remove directories that should not be in the shipped packages
echo -ne "\\n\\n[+] Removing unneeded/unshipable files and folders\\n\\n"
rm -Rf ${RELEASE_DIR}/build
rm -Rf ${RELEASE_DIR}/scripts/DONOTSHIP
rm -Rf ${RELEASE_DIR}/extras
find ${RELEASE_DIR}/heatmaps/src/* -type d -exec rm -Rf {} \; 2> /dev/null 

# Set additional permissions on folders
echo -ne "[+] Setting permissions on hlstatsimg/games directory\\n\\n"
find ${RELEASE_DIR}/web/hlstatsimg/games/ -type d -exec chmod 777 {} \; > /dev/null

# Symlink the HLXCE plugins and compile
echo -ne "[+] Setting up symlinks for HLXCE plugin compile\\n\\n"
ln -fs ${RELEASE_DIR}/sourcemod/scripting/*.sp ${SOURCEMOD_DIR}/ > /dev/null
ln -fs ${RELEASE_DIR}/sourcemod/scripting/include/*.inc ${SOURCEMOD_DIR}/include/ > /dev/null
ln -fs ${RELEASE_DIR}/amxmodx/scripting/*.sma ${AMXMODX_DIR}/ > /dev/null
mkdir ${RELEASE_DIR}/sourcemod/plugins
mkdir ${RELEASE_DIR}/amxmodx/plugins

echo -ne "${DIVIDER}\\n\\n[+] Compiling SourceMod Plugin \\n\\n"
cd ${SOURCEMOD_DIR} 
for sm_source in hlstats*.sp
do
	grep "VERSION \"${VERSION}\"" ${sm_source} -q 
	if [ $? -ne 0 ]; then
		echo -ne "${DIVIDER}\\n\\n [!] WARNING: Build version number (${VERSION}) was not found in SM Plugin ${sm_source}.\n"
                echo -ne "     Is this correct?\\n\\n${DIVIDER}\\n\\n"
		sleep 5
	fi
	smxfile="`echo ${sm_source} | sed -e 's/\.sp$/.smx/'`"
	./spcomp ${sm_source} -o${RELEASE_DIR}/sourcemod/plugins/${smxfile} | grep -q Error
	if [ $? = 0 ]; then
		echo " [!] WARNING: ${smxfile} DID NOT COMPILE SUCCESSFULLY."
		exit
	else
		echo " [+] ${smxfile} compiled successfully."
	fi
	echo -ne "\\n"
done
echo -ne "[+] SourceMod plugins compiled \\n\\n${DIVIDER}\\n\\n"

echo -ne "[+] Compiling AMXMODX plugins \\n\\n"
cd ${AMXMODX_DIR}
for amx_source in hlstatsx_*.sma
do
        grep "VERSION \"${VERSION} (HL1)\"" ${amx_source} -q
        if [ $? -ne 0 ]; then
                echo -ne "${DIVIDER}\\n\\n [!] WARNING: Build version number (${VERSION}) was not found in AMX plugin ${amx_source}.\n"
		echo -ne "     Is this correct?\\n\\n${DIVIDER}\\n\\n"
                sleep 5
        fi

	amxxfile="`echo ${amx_source} | sed -e 's/\.sma$/.amxx/'`"
	./amxxpc ${amx_source} -o${RELEASE_DIR}/amxmodx/plugins/${amxxfile} | grep -q Done
	if [ $? -eq 0 ]; then
		echo " [+] ${amxxfile} compiled successfully"
	else
		echo " [!] WARNING: ${amxxfile} DID NOT COMPILE SUCCESSFULLY."
		exit
	fi
	echo -ne "\\n"
done
echo -ne \\n
echo -ne "[+] AMXMODX plugins compiled \\n\\n${DIVIDER}\\n\\n"

cd ${RELEASE_DIR}
rm ${OUTPUT_DIR}/${PKG_PREFIX}${VERSION}FULL.tgz 2> /dev/null
rm ${OUTPUT_DIR}/${PKG_PREFIX}${VERSION}FULL.zip 2> /dev/null
echo -ne "[+] Creating FULL ${VERSION} TGZ package\\n\\n"
tar -pczf ${OUTPUT_DIR}/${PKG_PREFIX}${VERSION}FULL.tgz *
echo -ne "[+] Creating FULL ${VERSION} ZIP package\\n\\n"
zip -r ${OUTPUT_DIR}/${PKG_PREFIX}${VERSION}FULL.zip * > /dev/null
echo -ne "[+] FULL packages created!\\n\\n"

if [ "$2" != "" ]; then
	if [ "$3" == "" ]; then
		ENDREV=HEAD
	else
		ENDREV=$3
	fi
	echo -ne "${DIVIDER}\\n\\n"
	echo -ne "[+] Starting generation of UPGRADE packages.\\n\\n"
	rm -Rf ${RELEASE_DIR}

	mkdir -p ${RELEASE_DIR}/web/
	echo -ne "[+] Exporting required files for every update.\\n\\n"
        svn export ${TRUNK_DIR}/sourcemod ${RELEASE_DIR}/sourcemod > /dev/null
        svn export ${TRUNK_DIR}/amxmodx ${RELEASE_DIR}/amxmodx > /dev/null
        svn export ${TRUNK_DIR}/web/updater ${RELEASE_DIR}/web/updater > /dev/null
	svn export ${TRUNK_DIR}/ ${RELEASE_DIR}/ --force --depth=files > /dev/null

	echo -ne "[+] Exporting ${TRUNK_DIR} from rev $2 to ${ENDREV}\\n\\n"
	for i in $(svn diff --summarize -r $2:${ENDREV} ${TRUNK_DIR} | awk '{ print $2 }');
	do
		p=$(echo $i | sed -e "s%${TRUNK_DIR}/%%");
		mkdir -p ${RELEASE_DIR}/$(dirname $p);
		svn export $i ${RELEASE_DIR}/$p --force -q 2> /dev/null;
	done

	# Remove directories that should not be in the shipped packages
	echo -ne "[+] Removing unneeded/unshipable files and folders\\n\\n"
	rm -Rf ${RELEASE_DIR}/build
	rm -Rf ${RELEASE_DIR}/scripts/DONOTSHIP
	rm -Rf ${RELEASE_DIR}/extras
	rm -Rf ${RELEASE_DIR}/sql
	rmdir -p --ignore-fail-on-non-empty ${RELEASE_DIR}/heatmaps/src/* 2> /dev/null

	# Set additional permissions on folders
	echo -ne "[+] Setting permissions on hlstatsimg/games directory\\n\\n"
	find ${RELEASE_DIR}/web/hlstatsimg/games/ -type d -exec chmod 777 {} \; 2> /dev/null

	# Symlink the HLXCE plugins and compile
	echo -ne "[+] Setting up symlinks for HLXCE plugin compile\\n\\n"
	ln -fs ${RELEASE_DIR}/sourcemod/scripting/*.sp ${SOURCEMOD_DIR}/ > /dev/null
	ln -fs ${RELEASE_DIR}/sourcemod/scripting/include/*.inc ${SOURCEMOD_DIR}/include/ > /dev/null
	ln -fs ${RELEASE_DIR}/amxmodx/scripting/*.sma ${AMXMODX_DIR}/ > /dev/null
	mkdir ${RELEASE_DIR}/sourcemod/plugins
	mkdir ${RELEASE_DIR}/amxmodx/plugins

	echo -ne "${DIVIDER}\\n\\n[+] Compiling SourceMod Plugin \\n\\n"
	cd ${SOURCEMOD_DIR}
	for sm_source in hlstats*.sp
	do
	        smxfile="`echo ${sm_source} | sed -e 's/\.sp$/.smx/'`"
        	./spcomp ${sm_source} -o${RELEASE_DIR}/sourcemod/plugins/${smxfile} | grep -q Error
	        if [ $? = 0 ]; then
	                echo " [!] WARNING: ${smxfile} DID NOT COMPILE SUCCESSFULLY."
	                exit
	        else
	                echo " [+] ${smxfile} compiled successfully."
	        fi
	done
	echo -ne \\n
	echo -ne "[+] SourceMod plugins compiled \\n\\n${DIVIDER}\\n\\n"
	
	echo -ne "[+] Compiling AMXMODX plugins \\n\\n"
	cd ${AMXMODX_DIR}
	for amx_source in hlstatsx_*.sma
	do
	        amxxfile="`echo ${amx_source} | sed -e 's/\.sma$/.amxx/'`"
	        ./amxxpc ${amx_source} -o${RELEASE_DIR}/amxmodx/plugins/${amxxfile} | grep -q Done
	        if [ $? -eq 0 ]; then
	                echo " [+] ${amxxfile} compiled successfully"
	        else
	                echo " [!] WARNING: ${amxxfile} DID NOT COMPILE SUCCESSFULLY."
	                exit
	        fi
	done
	echo -ne \\n
	echo -ne "[+] AMXMODX plugins compiled \\n\\n${DIVIDER}\\n\\n"
	
	cd ${RELEASE_DIR}
	rm ${OUTPUT_DIR}/${PKG_PREFIX}${VERSION}UPGRADE.tgz 2> /dev/null
	rm ${OUTPUT_DIR}/${PKG_PREFIX}${VERSION}UPGRADE.zip 2> /dev/null
	echo -ne "${DIVIDER}\\n\\n[+] Creating UPGRADE ${VERSION} TGZ package\\n\\n"
	tar -pczf ${OUTPUT_DIR}/${PKG_PREFIX}${VERSION}UPGRADE.tgz *
	echo -ne "[+] Creating UPGRADE ${VERSION} ZIP package\\n\\n"
	zip -r ${OUTPUT_DIR}/${PKG_PREFIX}${VERSION}UPGRADE.zip * > /dev/null
	echo -ne "[+] UPGRADE packages created!\\n\\n"
fi

echo -ne "${DIVIDER}\\n\\n[+] Build process complete.\\n\\nYUR A SMACKHEAD.  Have a nice day! \\n\\n"
exit 0
