<?php
# HLXCE Buildbot Wrapper Script
#
# This script is called by GoogleCode when a push is detected.
# Based on what the rev was we decide to build a stable or dev package.
?>

<html>
<head>
	<title>HLstatsX Community Edition: Build Bot wrapper</title>
	<style type="text/css">
		#shell_output
		{
			width:80%;
			height: 600px;
		}
	</style>
</head>

<body>
	<h2>HLstatsX Community Edition &mdash; Build Bot wrapper</h2>
	<p>To build a release package fill out the appropriate fields below.  Packages will be placed in <a href="/release/">the release directory</a> when they are complete.  The output from the build script can be found below.</p>

	<form action="build.php" method="post">
		<label for="release_number">Release Number: </label>
		<input type="text" name="release_number" value="1.6.10">
		<br /><br />
		<label for="repository">Repository: </label>
		<select name="repository">
			<option value="hlx-dev" selected>Development Branch</option>
			<option value="hlx-16">1.6.X Branch</option>
		</select><br /><br />
		<label for="upgrade_rev">Upgrade Tag/Rev: </label>
		<input type="text" name="upgrade_rev" /><br /><br />
		<label for="test_only">Test only (ignore verioning errors): </label>
		<input type="checkbox" name="test_only" value="test_only" /><br /><br />
		<input type="hidden" name="form_submitted" value="1" />
		<input type="submit" value="Start Build" />
	</form>
<?php

if (isset($_POST['form_submitted']) && ($_POST['form_submitted'] == 1))
{
	// Grab posted variables
	if (isset($_POST['repository']))
	{
		$repository = escapeshellarg($_POST['repository']);
	}
	if (isset($_POST['release_number']))
	{
		$release_number = escapeshellarg($_POST['release_number']);
	}
	if (isset($_POST['upgrade_rev']))
	{
		$upgrade_rev = escapeshellarg($_POST['upgrade_rev']);
	}

	if (isset($_POST['test_only']))
	{
		$test_only = 1;
	}
	else
	{
		$test_only = 0;
	}
?>
	<textarea id="shell_output">
<?php	
	passthru("/usr/bin/sudo -u hg /home/hg/hlx_buildbot/build_release.sh $repository $release_number $upgrade_rev $test_only");
?>
	</textarea>
<?php
}
?>

</body>
</html>


