#!/usr/bin/perl

# Usage: Send logs to STDIN as if doing log import with hlstats.pl. Codes will be outputted to output.txt (make sure there is write access)

$start_time    = time();

$g_timestamp       = 1;
$start_parse_time  = time();
$import_logs_count = 0;
$s_output = "";

%g_pactions = ();
%g_ppactions = ();
%g_tactions = ();
%g_wactions = ();
%g_weapons = ();
%g_teams = ();
%g_roles = ();

print "PARSER: Started parsing logs. Every dot signs 500 parsed lines\n";

# Main data loop
$c = 0;

while (defined($loop = <STDIN>)) {
	$s_output = $loop;
	if (($import_logs_count > 0) && ($import_logs_count % 500 == 0)) {
		$parse_time = time() - $start_parse_time;
		if ($parse_time == 0) {
			$parse_time++;
		}
		print ". [".($parse_time)." sec (".sprintf("%.3f", (500 / $parse_time)).")]\n";
		$start_parse_time = time();
	}
	
	$s_output =~ s/[\r\n\0]//g;	# remove naughty characters
	$s_output =~ s/\[No.C-D\]//g;	# remove [No C-D] tag
	$s_output =~ s/\[OLD.C-D\]//g;	# remove [OLD C-D] tag
	$s_output =~ s/\[NOCL\]//g;	# remove [NOCL] tag
	$s_output =~ s/\([12]\)//g;	# strip (1) and (2) from player names
	$s_output =~ s/^(?:.*?)?L (\d\d)\/(\d\d)\/(\d{4}) - (\d\d):(\d\d):(\d\d):\s*//; #strip timestamp
	
	#if ($s_output !~ s/^(?:.*?)?L (\d\d)\/(\d\d)\/(\d{4}) - (\d\d):(\d\d):(\d\d):\s*//) {
	#	print "MALFORMED DATA: $s_output\n";
	#	next;
	#}
	
	if ($s_output =~ /^
			(?:\([^\(\)]+\))?		# l4d prefix, such as (DEATH) or (INCAP)
			"(?:.+?(?:<.+?>)*?
			(?:<setpos_exact\s(?:|-)\d+?\.\d\d\s(?:|-)\d+?\.\d\d\s(?:|-)\d+?\.\d\d;.*?)?
			)"						# player string with or without l4d-style location coords
			\s([^"\(]+)\s			# verb (ex. attacked, killed, triggered)
			"(.+?(?:<.+?>)*?
			(?:<setpos_exact\s(?:|-)\d+?\.\d\d\s(?:|-)\d+?\.\d\d\s(?:|-)\d+?\.\d\d;.*?)?
			)"						# player string as above or action name
			\s[^"\(]+\s				# (ex. with, against)
			"(.+?(?:<.+?>)*?
			(?:<setpos_exact\s(?:|-)\d+?\.\d\d\s(?:|-)\d+?\.\d\d\s(?:|-)\d+?\.\d\d;.*?)?
			)"						# player string as above or weapon name
			(?:\s[^"\(]+\s"(.+?)")?	# weapon name on plyrplyr actions
			.*						#properties
			$/x)
	{
		$ev_verb   = $1; # killed; attacked; triggered
		$ev_obj_a  = $2; # kill:victim; action:actionname
		$ev_obj_b  = $3; # kill:weapon; action:victim
		$ev_obj_c  = $4; # action:weapon
		
		if (like($ev_verb, "killed") || like($ev_verb, "was incapped by")) {
			$g_weapons{$ev_obj_b}++;
		} elsif (like($ev_verb, "triggered")) {
			$g_ppactions{$ev_obj_a}++;
		} elsif (like($ev_verb, "triggered a")) {
			$g_pactions{$ev_obj_a}++;
		}
	} elsif ($s_output =~ /^".+?(?:<.+?>)*?(?:|<setpos_exact (?:|-)\d+?\.\d\d (?:|-)\d+?\.\d\d (?:|-)\d+?\.\d\d;.*?)" ([^"\(]+) "(.+?)".*$/) {
		$ev_verb   = $1;
		$ev_obj_a  = $2;
		
		if (like($ev_verb, "committed suicide with")) {
			$g_weapons{$ev_obj_a}++;
		} elsif (like($ev_verb, "joined team")) {
			$g_teams{$ev_obj_a}++;
		} elsif (like($ev_verb, "changed role to")) {
			$g_roles{$ev_obj_a}++;
		} elsif (like($ev_verb, "triggered") || like($ev_verb, "triggered a")) {
			$g_pactions{$ev_obj_a}++;
		}
	} elsif ($s_output =~ /^Team ".+?" ([^"\(]+) "(.+?)".*$/) {
		$ev_verb   = $1;
		$ev_obj_a  = $2;
		
		if (like($ev_verb, "triggered") || like($ev_verb, "triggered a")) {
			$g_tactions{$ev_obj_a}++;
		}
	} elsif ($s_output =~ /^([^"\(]+) "([^"]+)".*$/) {
		$ev_verb   = $1;
		$ev_obj_a  = $2;
		
		if (like($ev_verb, "World triggered")) {
			$g_wactions{$ev_obj_a}++;
		}
	}
	
	$c++;
	$c = 1 if ($c > 500000);
	$import_logs_count++;
}

$end_time = time();

if ($import_logs_count > 0) {
	print "\n";
}  
print "PARSER: Parsing of log file complete. Parsed ".$import_logs_count." lines in ".($end_time-$start_time)." seconds\n";
print "CODECATCHER: Readying output...\n";

open OUTPUTTEXT, ">output.txt";
print OUTPUTTEXT "HLX:CE CodeCatcher by psychonic\n\n\n";
print OUTPUTTEXT "Player Actions:\n";
while(my ($key, $value) = each(%g_pactions)) {
	print OUTPUTTEXT "$key ($value)\n";
}
print OUTPUTTEXT "\nPlayer-Player Actions:\n";
while(my ($key, $value) = each(%g_ppactions)) {
	print OUTPUTTEXT "$key ($value)\n";
}
print OUTPUTTEXT "\nTeam Actions:\n";
while(my ($key, $value) = each(%g_tactions)) {
	print OUTPUTTEXT "$key ($value)\n";
}
print OUTPUTTEXT "\nWorld Actions:\n";
while(my ($key, $value) = each(%g_wactions)) {
	print OUTPUTTEXT "$key ($value)\n";
}
print OUTPUTTEXT "\nWeapons:\n";
while(my ($key, $value) = each(%g_weapons)) {
	print OUTPUTTEXT "$key ($value)\n";
}
print OUTPUTTEXT "\nTeams:\n";
while(my ($key, $value) = each(%g_teams)) {
	print OUTPUTTEXT "$key ($value)\n";
}
print OUTPUTTEXT "\nRoles:\n";
while(my ($key, $value) = each(%g_roles)) {
	print OUTPUTTEXT "$key ($value)\n";
}

close OUTPUTTEXT;


print "CODECATCHER: Finished outputting findings to output.txt\n";

sub like
{
	my ($subject, $compare) = @_;
	
	if ($subject =~ /^\s*\Q$compare\E\s*$/) {
		return 1;
	} else {
		return 0;
	}
}