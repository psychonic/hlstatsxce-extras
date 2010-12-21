<?php

// Upload.php
// Script provides a list of files, input boxes and opportunity to enter credentials and then uploads files to Google Code

// Configure these variables pl0x:

// Location of built packages
$package_dir="/home/hg/hlx_buildbot/output/release";

// Location of Google Code python upload script
$google_script="/home/hg/utilities/googlecode/googlecode_upload.py";

// -- Nothing left to configure --

// Get a list of files
$files = scandir($package_dir);

// Print out global HTML
?>
<html>
<head>
  <title>HLXCE GoogleCode Release Uploader</title>
    <style type="text/css">
    .col1, .col2, .col3, .col4 
    {
      width:280px;
    }

    #filename, #summary, #labels
    {
      width:100%;
    }
  </style>
</head>
<body>
	<h2>HLXCE GoogleCode Release Uploader</h2>
<?php

// Begin fork
if (isset($_POST['submit']))
{
  if (!empty($_POST['username']) && !empty($_POST['password']))
  {
    $username = escapeshellarg($_POST['username']);
    $password = escapeshellarg($_POST['password']);
    

    // Loop through each file and pull appropriate items from _POST
    foreach($files as $file)
    {
      if (($file != '.') && ($file !='..'))
      {
        $enc_file = preg_replace('/\\./', '_', $file);
        // Check if this file should be uploaded -- if not, we're done
        if (isset($_POST["{$enc_file}-upload"]))
        {
          // File should be uploaded -- get the post variables for it and go
          $summary = escapeshellarg($_POST["{$enc_file}-summary"]);
          $labels = escapeshellarg($_POST["{$enc_file}-labels"]);
          print "<p>Attempting to upload $file to Google Code...<br />";
          exec("$google_script -p hlstatsxcommunity -s $summary -u $username -w $password -l $labels $package_dir/$file", $output, $return);
          if ($return == 0)
          {
            print "$file uploaded successfully.</p>";
          }
          else
          {
            print "<strong>WARNING:</strong> $file not uploaded.<br /><br /><textarea style=\"width:60%; height:100px;\">";
            foreach($output as $line)
            {
              print "$line \n";
            }
            print '</textarea></p><hr>';
          }
        }
      }
    }
  }
  else
  {
    print "No username and password combination entered.  Please go back and resubmit.";
  }
}
else
{
  ?>
    <p>Please fill in the summary information (a general idea has been pre-filed), along with credentials, and these packages will be uploaded to Google Code</p>

    <form action="<?php echo $PHP_SELF; ?>" method="post">
    <table>
    <tr>
      <th class="col1">Filename</th>
      <th class="col2">Summary</th>
      <th class="col3">Labels</th>
      <th class="col4">Upload?</th>
    </tr>

    <?php
  foreach($files as $file) {
    if (($file != '.') && ($file !='..')) {
      $version="UNKNOWN";
      $type="UNKNOWN";
      $OS="UNKNOWN";

      // Determine version number
      if (preg_match('/(\d+\.\d+\.\d+)/', $file, $matches))
      {
        $version = $matches[1];
      }
      
      // Determine package type
      if (preg_match('/UPGRADE/', $file))
      {
        $type = "UPGRADE";
      }
      elseif (preg_match('/FULL/', $file))
      {
        $type = "FULL";
      }

      // Determine OS
      if (preg_match('/gz$/', $file))
      {
        $OS = "Linux";
      }
      elseif (preg_match('/zip$/', $file))
      {
        $OS = "All";
      }

      // Assemble the summary
      $summary = 'HLstatsX Community Edition ' . $version . ' ' . ucfirst(strtolower($type));

      // Assemble the labels
      $labels = 'Featured,Type-Archive,Opsys-' . $OS;
      
        
      print "
      <tr>
        <td><input type=\"text\" value=\"$file\" name=\"$file\" id=\"filename\" readonly></td>
        <td><input type=\"text\" value=\"$summary\" name=\"$file-summary\" id=\"summary\"></td>
        <td><input type=\"text\" value=\"$labels\" name=\"$file-labels\" id=\"labels\"></td>
        <td><input type=\"checkbox\" name=\"$file-upload\" value=\"1\"></td>
      </tr>
      ";
    }
  }
  ?>

    <tr>
      <td>Enter your Google Code Username and Password</td>
      <td><input type="text" name="username"></td>
      <td><input type="password" name="password"></td>
      <td><input type="submit" name="submit"></td>
    </tr>
    </table>
    </form>
<?php
}
?>
</body>
</html>
