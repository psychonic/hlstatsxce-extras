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

# Location of the repositories
REPO_HEAD=/home/hg/repository/hlxce

# Temporary location to build the package
TMP_DIR=/tmp/hlx-build-release

# Location to output full and release packages
OUTPUT_DIR=/home/hg/hlx_buildbot/output/release

# Package Prefix
# Example: HLXCommunityEdition
PKG_PREFIX=HLXCommunityEdition

# Configure the absolute path to the Sourcemod Scripting folder
# Used to compile sourcemod plugins (when applicable)
SOURCEMOD_DIR=/home/hg/utilities/sourcemod/addons/sourcemod/scripting

# Configure the absolute path to the AMXmodX Scripting folder
# Used to compile AMX plugins
AMXMODX_DIR=/home/hg/utilities/amxmodx/addons/amxmodx/scripting

# NOTHING TO CHANGE BELOW THIS LINE
# -----------------------------------------------------------------------------

# Get the current directory
CURRENT_DIR=`pwd`


REPOSITORY=$1
RELEASE_NUMBER=$2
UPGRADE_REV=$3
TEST_ONLY=$4

# Check if the necessary arguments were passed
if [[ -n "${REPOSITORY}" && -n "${RELEASE_NUMBER}" ]]; then

	# Check if we have a local copy of the repository that should be built
	if [ ! -d "${REPO_HEAD}/${REPOSITORY}" ]; then
		echo "Warning: Could not find a folder for ${REPO_HEAD}/${REPOSITORY}.  Please verify paths and try again."
		exit
	else
		# Set up where our source repository is and build location.
		# Check that the build location does not exist.  If it does, delete and create.
		REPOSITORY=${REPO_HEAD}/${REPOSITORY}
		BUILD_LOCATION=${TMP_DIR}/${RELEASE_NUMBER}-full
		if [ -d "${BUILD_LOCATION}" ]; then
			rm -Rf ${BUILD_LOCATION}
		fi
		mkdir -p ${BUILD_LOCATION}
	fi

	# Check that we can write to the output directory
	if [ ! -w "${OUTPUT_DIR}" ]; then
		echo "[!] CRITICAL: Cannot write to the output directory ${OUTPUT_DIR}"
		exit
	else
		# We can write, clean out the directory.
		rm -Rf ${OUTPUT_DIR}/*
	fi

	echo -ne "[+] Building full package for Release #${RELEASE_NUMBER} from repository ${REPOSITORY}.\\n\\n"

	# Call hg to update the local development repository
	echo -ne "[+] Updating local development repository\\n"
	cd ${REPOSITORY}
	/usr/bin/hg pull > /dev/null
	/usr/bin/hg update -C > /dev/null

	# Archive out the repository for further changes
	echo -ne "[+] Creating temporary build location at ${BUILD_LOCATION}.\\n"	
	/usr/bin/hg archive ${BUILD_LOCATION}

	# Check that version numbers have been rolled up
	# install.sql
	grep -q "@VERSION=\"${RELEASE_NUMBER}\"" ${BUILD_LOCATION}/sql/install.sql 
	if [ $? -eq 1 ]; then
		echo ""
		echo " [!] WARNING: Version number ${RELEASE_NUMBER} not found in install.sql."
		echo ""
		WRONG_VERSION_NUMBER=1
	fi
	# upgrade.php
	grep -q "'${RELEASE_NUMBER}'" ${BUILD_LOCATION}/web/updater/*.php
	if [ $? -eq 1 ]; then
		echo ""
		echo " [!] WARNING: Version number ${RELEASE_NUMBER} not found in any updater file."
		echo ""
		WRONG_VERSION_NUMBER=1
	fi
	# SourceMod plugin
	grep -q "VERSION \"${RELEASE_NUMBER}\"" ${BUILD_LOCATION}/sourcemod/scripting/*.sp
        if [ $? -eq 1 ]; then
		echo ""
                echo " [!] WARNING: Version number ${RELEASE_NUMBER} not found in any SourceMod plugin file."
		echo ""
		WRONG_VERSION_NUMBER=1
        fi

        # AMXModX plugin
        grep -q "VERSION \"${RELEASE_NUMBER}" ${BUILD_LOCATION}/amxmodx/scripting/*.sma
        if [ $? -eq 1 ]; then
		echo ""
                echo " [!] WARNING: Version number ${RELEASE_NUMBER} not found in any AMXModX plugin file."
		echo ""
		WRONG_VERSION_NUMBER=1
        fi

	if [ ${WRONG_VERSION_NUMBER} -eq 1 -a ${TEST_ONLY} -eq 0 ]; then
		echo "[!] Terminating Build due to invalid versioning."
		echo "[!] Removing temporary build files."
		rm -Rf ${BUILD_LOCATION}
		exit
	fi

	# Remove directories that should not be in the shipped packages
	echo -ne "[+] Removing unneeded/unshipable files and folders\\n"
	
	rm -Rf ${BUILD_LOCATION}/scripts/DONOTSHIP
	find ${BUILD_LOCATION}/heatmaps/src/* -type d -exec rm -Rf {} \; &> /dev/null


	# Set additional permissions on folders
	echo -ne "[+] Setting permissions on hlstatsimg/games directory\\n"
	find ${BUILD_LOCATION}/web/hlstatsimg/games/ -type d -exec chmod 777 {} \; &> /dev/null

	# Symlink the HLXCE plugins and compile
	echo -ne "[+] Setting up symlinks for HLXCE plugin compile\\n\\n"
	ln -fs ${BUILD_LOCATION}/sourcemod/scripting/*.sp ${SOURCEMOD_DIR}/ &> /dev/null
	ln -fs ${BUILD_LOCATION}/sourcemod/scripting/include/*.inc ${SOURCEMOD_DIR}/include/ &> /dev/null
	ln -fs ${BUILD_LOCATION}/amxmodx/scripting/*.sma ${AMXMODX_DIR}/ &> /dev/null
	mkdir ${BUILD_LOCATION}/sourcemod/plugins &> /dev/null
	mkdir ${BUILD_LOCATION}/amxmodx/plugins &> /dev/null

	echo -ne "[+] Compiling SourceMod Plugin\\n"
	cd ${SOURCEMOD_DIR}
	for sm_source in hlstats*.sp
	do
			smxfile="`echo ${sm_source} | sed -e 's/\.sp$/.smx/'`"
			./spcomp ${sm_source} -o${BUILD_LOCATION}/sourcemod/plugins/${smxfile} | grep -q Error
			if [ $? = 0 ]; then
					echo " [!] WARNING: ${smxfile} DID NOT COMPILE SUCCESSFULLY."
					exit
			else
					echo " [+] ${smxfile} compiled successfully."
			fi
	done
	echo -ne "[+] SourceMod plugins compiled \\n\\n"
	# Do some cleanup
	cd ${BUILD_LOCATION}/sourcemod/scripting
	find *.sp -type f -exec rm ${SOURCEMOD_DIR}/{} \;
	cd include
	find *.inc -type f -exec rm ${SOURCEMOD_DIR}/include/{} \;	
	
	echo -ne "[+] Compiling AMXMODX plugins\\n"
	cd ${AMXMODX_DIR}
	for amx_source in hlstatsx_*.sma
	do
			amxxfile="`echo ${amx_source} | sed -e 's/\.sma$/.amxx/'`"
			./amxxpc ${amx_source} -o${BUILD_LOCATION}/amxmodx/plugins/${amxxfile} | grep -q Done
			if [ $? -eq 0 ]; then
					echo " [+] ${amxxfile} compiled successfully"
			else
					echo " [!] WARNING: ${amxxfile} DID NOT COMPILE SUCCESSFULLY."
					exit
			fi
	done
	echo -ne "[+] AMXMODX plugins compiled \\n\\n"
	# Do some cleanup
	cd ${BUILD_LOCATION}/amxmodx/scripting
	find *.sma -type f -exec rm ${AMXMODX_DIR}/{} \;	
	
	
	# Build shipping packages
	echo -ne "[+] Creating compressed packages \\n"
	cd ${BUILD_LOCATION}
	echo -ne " [+] Creating TGZ package\\n"
	tar --owner=0 --group=users -czf ${OUTPUT_DIR}/${PKG_PREFIX}${RELEASE_NUMBER}FULL.tar.gz *
	echo -ne " [+] Creating ZIP package\\n"
	zip -rq ${OUTPUT_DIR}/${PKG_PREFIX}${RELEASE_NUMBER}FULL.zip * > /dev/null
	echo -ne "[+] Packages created\\n\\n"

	echo -ne "[+] Full package for ${RELEASE_NUMBER} complete.\\n\\n\\n"


	# Cleanup
	rm -Rf ${BUILD_LOCATION}


	# Handle upgrade package if necessary.
	if [ -n "${UPGRADE_REV}" ]; then
		echo -ne "[+] Building upgrade package for Release #${RELEASE_NUMBER} from repository ${REPOSITORY}.\\n\\n"

		# Set up where our source repository is and build location.
		# Check that the build location does not exist.  If it does, delete and create.
		BUILD_LOCATION=${TMP_DIR}/${RELEASE_NUMBER}-upgrade
		echo -ne "[+] Creating temporary build location at ${BUILD_LOCATION}.\\n"
		if [ -d "${BUILD_LOCATION}" ]; then
			rm -Rf ${BUILD_LOCATION}
		fi
		mkdir -p ${BUILD_LOCATION}

		# Copy necessary files for every release
		cd ${REPOSITORY}
		cp * ${BUILD_LOCATION}
		mkdir ${BUILD_LOCATION}/sourcemod
		cp -R sourcemod ${BUILD_LOCATION}
		mkdir ${BUILD_LOCATION}/amxmodx
		cp -R amxmodx ${BUILD_LOCATION}
		mkdir -p ${BUILD_LOCATION}/web/updater
		cp web/updater/index.php ${BUILD_LOCATION}/web/updater/index.php

		# Copy changed files to build location
		cd ${REPOSITORY}
		tar cf /tmp/hlx-upgrade.tar `hg status --rev $UPGRADE_REV | cut -c3- `
		cd ${BUILD_LOCATION}
		tar xf /tmp/hlx-upgrade.tar
		rm /tmp/hlx-upgrade.tar


		# Remove directories that should not be in the shipped packages
		echo -ne "[+] Removing unneeded/unshipable files and folders\\n"
		
		rm -f ${BUILD_LOCATION}/scripts/hlstats.conf
		rm -Rf ${BUILD_LOCATION}/scripts/DONOTSHIP
		rm -Rf ${BUILD_LOCATION}/sql

		find ${BUILD_LOCATION}/heatmaps/src/* -type d -exec rm -Rf {} \; &> /dev/null


		# Set additional permissions on folders
		echo -ne "[+] Setting permissions on hlstatsimg/games directory\\n"
		find ${BUILD_LOCATION}/web/hlstatsimg/games/ -type d -exec chmod 777 {} \; &> /dev/null

		# Symlink the HLXCE plugins and compile
		echo -ne "[+] Setting up symlinks for HLXCE plugin compile\\n\\n"
		ln -fs ${BUILD_LOCATION}/sourcemod/scripting/*.sp ${SOURCEMOD_DIR}/ &> /dev/null
		ln -fs ${BUILD_LOCATION}/sourcemod/scripting/include/*.inc ${SOURCEMOD_DIR}/include/ &> /dev/null
		ln -fs ${BUILD_LOCATION}/amxmodx/scripting/*.sma ${AMXMODX_DIR}/ &> /dev/null
		mkdir ${BUILD_LOCATION}/sourcemod/plugins &> /dev/null
		mkdir ${BUILD_LOCATION}/amxmodx/plugins &> /dev/null

		echo -ne "[+] Compiling SourceMod Plugin\\n"
		cd ${SOURCEMOD_DIR}
		for sm_source in hlstats*.sp
		do
				smxfile="`echo ${sm_source} | sed -e 's/\.sp$/.smx/'`"
				./spcomp ${sm_source} -o${BUILD_LOCATION}/sourcemod/plugins/${smxfile} | grep -q Error
				if [ $? = 0 ]; then
						echo " [!] WARNING: ${smxfile} DID NOT COMPILE SUCCESSFULLY."
						exit
				else
						echo " [+] ${smxfile} compiled successfully."
				fi
		done
		echo -ne "[+] SourceMod plugins compiled \\n\\n"
		# Do some cleanup
		cd ${BUILD_LOCATION}/sourcemod/scripting
		find *.sp -type f -exec rm ${SOURCEMOD_DIR}/{} \;
		cd include
		find *.inc -type f -exec rm ${SOURCEMOD_DIR}/include/{} \;	
		
		echo -ne "[+] Compiling AMXMODX plugins\\n"
		cd ${AMXMODX_DIR}
		for amx_source in hlstatsx_*.sma
		do
				amxxfile="`echo ${amx_source} | sed -e 's/\.sma$/.amxx/'`"
				./amxxpc ${amx_source} -o${BUILD_LOCATION}/amxmodx/plugins/${amxxfile} | grep -q Done
				if [ $? -eq 0 ]; then
						echo " [+] ${amxxfile} compiled successfully"
				else
						echo " [!] WARNING: ${amxxfile} DID NOT COMPILE SUCCESSFULLY."
						exit
				fi
		done
		echo -ne "[+] AMXMODX plugins compiled \\n\\n"
		# Do some cleanup
		cd ${BUILD_LOCATION}/amxmodx/scripting
		find *.sma -type f -exec rm ${AMXMODX_DIR}/{} \;	
	
		# Build shipping packages
		echo -ne "[+] Creating compressed packages \\n"
		cd ${BUILD_LOCATION}
		echo -ne " [+] Creating TGZ package\\n"
		tar --owner=0 --group=users -czf ${OUTPUT_DIR}/${PKG_PREFIX}${RELEASE_NUMBER}UPGRADE.tar.gz *
		echo -ne " [+] Creating ZIP package\\n"
		zip -rq ${OUTPUT_DIR}/${PKG_PREFIX}${RELEASE_NUMBER}UPGRADE.zip *
		echo -ne "[+] Packages created\\n\\n"

		echo -ne "[+] UPGRADE package for ${RELEASE_NUMBER} complete.\\n\\n\\n"

		rm -Rf ${BUILD_LOCATION}	
	fi
else
	echo "Usage: ./build_package.sh TRUNK_NAME RELEASE_NUMBER <UPGRADE_BEGIN_REV>."
	echo "Example: To build a full and upgrade package for 1.6.8 on the hlx-16 repository directory"
	echo "./build_package.sh hlx-16 1.6.8 340"
fi
