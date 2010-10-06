<html>
<head>
	<title>Interwave Community Post-web Builder</title>
</head>

<body>

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
	die("<p>This script can not be accessed directly.</p></body></html>");
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
		if (($build_dev) || ($build_stable)) 
		{
			exec("sudo -u hg /home/hg/hlx_buildbot/build_snapshot.sh $build_dev $build_stable", $output);
			foreach ($output as $line) {
				$message .= $line . "\n";
			}
			print "<pre>" . $message . "</pre>";


			# Send e-mail
			$to = "hlxce-devel@googlegroups.com";
			$subject = "Build log for recent commit to $repository";
	
			$headers = 	'From: buildbot@hlxce.com' . "\r\n" .
					'Reply-To: hlxce-devel@googlegroups.com' . "\r\n" .
					'X-Mailer: PHP/' . phpversion();
			mail($to, $subject, $message, $headers);
		}
	break;
}	

?>

</body>
</html>
