<?php

# HLXCE Buildbot Wrapper Script
#
# This script is called by GoogleCode when a push is detected.
# Based on what the rev was we decide to build a stable or dev package.

# To force generation, change $force to true and set the flag for either build_dev or
# build_stable.
#
# You can also call the script and specify these as GET parameters

$build_dev = 0;
$build_stable = 0;
$force = 0;

# Nothing to change below

if ((isset($_GET['force'])) && ($_GET['force'] == 1)) {
	$force = 1;
	if (isset($_GET['build_dev']) && ($_GET['build_dev'] == 1)) {
		$build_dev =1;
	}
	if (isset($_GET['build_stable']) && ($_GET['build_stable'] == 1)) {
		$build_stable = 1;
	}
}

# Obtain json data
if (($force == 0) && ($_GET['project'] == 'hlstatsxcommunity')) {
	$data = file_get_contents("php://input");
	$rev_data = json_decode($data);
	$repository = $rev_data->repository_path;
	if (!strpos($repository,"hlx-16")) {
		$build_dev = 1;
	} else {
		$build_stable = 1;
	}
}

if (($build_stable) || ($build_dev)) {
	echo "<html><head><title>Build Status</title></head><body><pre>";
	passthru("sudo -u hg /home/hg/hlx_buildbot/build_snapshot.sh $build_dev $build_stable");
	echo "</pre></body></html>";
} else {
	echo "Nothing to do!";
}


?>

