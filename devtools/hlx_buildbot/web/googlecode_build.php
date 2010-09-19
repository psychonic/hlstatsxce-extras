<?php

# Google Code Post-Commit build wrapper
#
# This script is called by GoogleCode when a push is detected.

// Check that we are getting a project parameter
if (isset($_GET['project'])) 
{
	$project = $_GET['project'];
}
else
{
	die("This script can not be accessed directly.");
}

switch ($project) {
	case "hlstatsxcommunity":
		$build_dev = 0;
		$build_stable = 0;
		$data = file_get_contents("php://input");
		$rev_data = json_decode($data);
		$repository = $rev_data->repository_path;
		if (!strpos($repository,"hlx-16")) 
		{
			$build_dev = 1;
		} 
		else
		{
			$build_stable = 1;
		}
		passthru("sudo -u hg /home/hg/hlx_buildbot/build_snapshot.sh $build_dev $build_stable");
	break;
}	
