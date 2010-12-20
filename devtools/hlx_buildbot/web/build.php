<?php
# HLXCE Buildbot Wrapper Script
#
# This script is called by GoogleCode when a push is detected.
# Based on what the rev was we decide to build a stable or dev package.

# Grab user entry if specified

if (isset($_POST['form_submitted']) && ($_POST['form_submitted'] == 1))
{
	$form_submitted = 1;
        // Grab posted variables
        if (isset($_POST['repository']))
        {
                $repository = $_POST['repository'];
        }
        if (isset($_POST['release_number']))
        {
                $release_number = $_POST['release_number'];
        }
        if (isset($_POST['upgrade_rev']))
        {
                $upgrade_rev = $_POST['upgrade_rev'];
        }

        if (isset($_POST['test_only']))
        {
                $test_only = 1;
        }
        else
        {
                $test_only = 0;
        }
}


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
	<p>To build a release package fill out the appropriate fields below.<br />
  Packages will be placed in <a href="/release/">the release directory</a> when they are complete.<br /><br />
  After build, the <a href="upload.php">Google Code Upload Script</a> can help get the files on GCode.<br /><br />
  The output from the build script can be found below.</p>

	<form action="<?php echo $PHP_SELF; ?>" method="post">
		<label for="release_number">Release Number: </label>
		<input type="text" name="release_number" value="<?php echo $release_number; ?>">
		<br /><br />
		<label for="repository">Repository: </label>
		<select name="repository">
			<option value="NULL" <?php if ($repository == "NULL") { echo "selected"; } ?>>Choose One...</option>
			<option value="hlx-dev" <?php if ($repository == "hlx-dev") { echo "selected"; } ?>>Development Branch</option>
			<option value="hlx-16" <?php if ($repository == "hlx-16") { echo "selected"; } ?>>1.6.X Branch</option>
		</select><br /><br />
		<label for="upgrade_rev">Upgrade Tag/Rev: </label>
		<input type="text" name="upgrade_rev" value="<?php echo $upgrade_rev; ?>" /><br /><br />
		<label for="test_only">Test only (ignore verioning errors): </label>
		<input type="checkbox" name="test_only" value="test_only" <?php if ($test_only == 1) { echo "checked=\"checked\""; } ?> /><br /><br />
		<input type="hidden" name="form_submitted" value="1" />
		<input type="submit" value="Start Build" />
	</form>

<?php

	if ($form_submitted) {
    echo '<p>Once the build is complete, you can <a href="upload.php">upload files to Google Code</a>.</p>';
		echo '<textarea id="shell_output">';
		$repository = escapeshellarg($repository);
		$release_number = escapeshellarg($release_number);
		$upgrade_rev = escapeshellarg($upgrade_rev);
		passthru("/usr/bin/sudo -u hg /home/hg/hlx_buildbot/build_release.sh $repository $release_number $upgrade_rev $test_only");
		echo '</textarea>';

	}
?>

</body>
</html>


