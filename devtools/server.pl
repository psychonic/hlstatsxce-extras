#!/usr/bin/perl
# Usage: ./server.pl logfile.txt
# Loads a logfile, and behaves as if it was a game server.
# 
use strict;
use warnings;

use IO::Socket;
use IO::Select;

# Where is the daemon?
my $daemon_host = "192.168.0.6";
my $daemon_port = "27500";

# How long should the delay be between log lines?
my $logline_delay = .05;

# Log file is taken from the command line, but you could hard-code it here
my $logfile_name = shift;

# Server status options
my %server_status = ();
$server_status{key} = 4294967295;
$server_status{type} = 73;
$server_status{netver} = 15;
$server_status{hostname} = "My local dummy server";
$server_status{mapname} = 'cp_blackmesa_final';
$server_status{gamedir} = 'tf';
$server_status{gamename} = 'Team Fortress';
$server_status{id} = 440;
$server_status{maxplayers} = 32;
$server_status{numbots} = 0;
$server_status{dedicated} = 100;
$server_status{os} = 119;
$server_status{passreq} = 0;
$server_status{secure} = 1;
$server_status{gamever} = 1.0.6.6;
$server_status{edf} = 160;
$server_status{port} = 27015;

##################### Just code below... #####################

my %players = ();
my %log_clients = ();


$|=1;

sub like
{
	my ($subject, $compare) = @_;
	
	if ($subject =~ /^\s*\Q$compare\E\s*$/) {
		return 1;
	} else {
		return 0;
	}
}

sub replyStatus
{
	my ($socket, %server) = @_;
	my $player_count = %players;
	my $datagram = pack("LCCZ*Z*Z*Z*vCCCCCCCZ*Cv",
		$server{key}, $server{type}, $server{netver}, $server{hostname},
		$server{mapname}, $server{gamedir}, $server{gamename},
		$server{id}, $player_count, $server{maxplayers},
		$server{numbots}, $server{dedicated}, $server{os},
		$server{passreq}, $server{secure}, $server{gamever},
		$server{edf}, $server{port});
	$socket->send($datagram);
}

sub getTimeStamp {
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time());
    return sprintf("%02d/%02d/%04d - %02d:%02d:%02d", $mon+1, $mday, $year+1900, $hour, $min, $sec);
	
}

sub addPlayer {
	my ($player_str) = @_;
	if($player_str =~ /^(.+?)<(\d+)><([^<>]*)><([^<>]*)>(?:<([^<>]*)>)?.*$/) {
		
		my %player_obj;
		my $name = $1;
		my $userid = $2;
		my $steamid = $3;
		$player_obj{"name"} = $name;
		$player_obj{"userid"} = $userid;
		$player_obj{"steamid"} = $steamid;	
		$player_obj{"state"} = "active";
		$player_obj{"addr"} = "10.0.0.1:27005";
		
		if(($userid) && ($steamid =~ /^STEAM/)) {
			if(!$players{$userid}) { 
				$players{$userid} = \%player_obj;
			}
			return $userid;
		} else {
			print("Player data matches, but is invalid: $player_str\n");
			
		}		
	} else {
		#print("Can't parse player data from $player_str\n");
	}
	return -1;
}

sub removePlayer {
	my ($player_str) = @_;
	if($player_str =~ /^(.+?)<(\d+)><([^<>]*)><([^<>]*)>(?:<([^<>]*)>)?.*$/) {
		my $userid = $2;
		if($players{$userid}) {
			delete($players{$userid});
		}
	} else {
		#print("Can't parse player data from $player_str\n");
	}
}

sub buildInitialPlayers {
	my ($file) = @_;
	
	my $line;
	my @connects = ();
	while($line = <$file>) {
		# strip timestamp
		$line =~ s/^(?:.*?)?L (\d\d)\/(\d\d)\/(\d{4}) - (\d\d):(\d\d):(\d\d):\s*//;
		
		if($line =~ /^
				(?:\([^\(\)]+\))?		# l4d prefix, such as (DEATH) or (INCAP)
				"(.+?(?:<.+?>)*?
				(?:<setpos_exact\s((?:|-)\d+?\.\d\d)\s((?:|-)\d+?\.\d\d)\s((?:|-)\d+?\.\d\d);.*?)?
				)"						# player string with or without l4d-style location coords
				\s([^"\(]+)\s			# verb (ex. attacked, killed, triggered)
				"(.+?(?:<.+?>)*?
				(?:<setpos_exact\s((?:|-)\d+?\.\d\d)\s((?:|-)\d+?\.\d\d)\s((?:|-)\d+?\.\d\d);.*?)?
				)"						# player string as above or action name
				\s[^"\(]+\s				# (ex. with, against)
				"(.+?(?:<.+?>)*?
				(?:<setpos_exact\s((?:|-)\d+?\.\d\d)\s((?:|-)\d+?\.\d\d)\s((?:|-)\d+?\.\d\d);.*?)?
				)"						# player string as above or weapon name
				(?:\s[^"\(]+\s"(.+?)")?	# weapon name on plyrplyr actions
				(.*)					#properties
				$/x
		){
			# player a did something to player b, possibly
			my $ev_player = $1;
			my $ev_verb   = $5; # killed; attacked; triggered
			my $ev_obj_a  = $6; # kill:victim; action:actionname
			my $ev_obj_b  = $10; # kill:weapon; action:victim
			if (like($ev_verb, "killed") || like($ev_verb, "was incapped by")) {
				# players are $ev_player and $ev_obj_b
				addPlayer($ev_player);
				addPlayer($ev_obj_b);
			} elsif (like($ev_verb, "triggered")) {
				# players are $ev_player and $ev_obj_b
				addPlayer($ev_player);
				addPlayer($ev_obj_b);
			} elsif (like($ev_verb, "triggered a")) {
				# player is just $ev_player
				addPlayer($ev_player);
			}
			
		} elsif ($line =~ /^"(.+?(?:<.+?>)*?(?:|<setpos_exact ((?:|-)\d+?\.\d\d) ((?:|-)\d+?\.\d\d) ((?:|-)\d+?\.\d\d);.*?))" ([^"\(]+) "(.+?)"(.*)$/) {
			# player a did something
			my $ev_player = $1;
			my $uniqueid = addPlayer($ev_player);
			my $ev_verb   = $5;
			if (like($ev_verb, "connected, address")) {
				# mark this id as a connection
				push(@connects, $uniqueid);
			}
		} elsif ($line =~ /^(?:Kick: |)"(.+?(?:<.+?>)*)" ([^\(]+)(.*)$/) {
			# player a did something (entered game, disconnected)
			my $ev_player = $1;
			my $ev_verb   = $2;
			my $uniqueid = addPlayer($ev_player);
			if (like($ev_verb, "entered the game")) {
				push(@connects, $uniqueid);
			}
		}
	}
	
	# since we're getting the initial state of the log, 
	# delete anyone who connected after the log started
	my $uniqueid;
	foreach $uniqueid (@connects) {
		if($players{$uniqueid}) {
			delete($players{$uniqueid});
		}
	}
	
	#reset the file
	seek($file,0,0);
	
}

sub parseLogLine {
	my ($line) = @_;
	
	my @connects = ();
		
	if($line =~ /^
				(?:\([^\(\)]+\))?		# l4d prefix, such as (DEATH) or (INCAP)
				"(.+?(?:<.+?>)*?
				(?:<setpos_exact\s((?:|-)\d+?\.\d\d)\s((?:|-)\d+?\.\d\d)\s((?:|-)\d+?\.\d\d);.*?)?
				)"						# player string with or without l4d-style location coords
				\s([^"\(]+)\s			# verb (ex. attacked, killed, triggered)
				"(.+?(?:<.+?>)*?
				(?:<setpos_exact\s((?:|-)\d+?\.\d\d)\s((?:|-)\d+?\.\d\d)\s((?:|-)\d+?\.\d\d);.*?)?
				)"						# player string as above or action name
				\s[^"\(]+\s				# (ex. with, against)
				"(.+?(?:<.+?>)*?
				(?:<setpos_exact\s((?:|-)\d+?\.\d\d)\s((?:|-)\d+?\.\d\d)\s((?:|-)\d+?\.\d\d);.*?)?
				)"						# player string as above or weapon name
				(?:\s[^"\(]+\s"(.+?)")?	# weapon name on plyrplyr actions
				(.*)					#properties
				$/x
	){
		# player a did something to player b, possibly
		my $ev_player = $1;
		my $ev_verb   = $5; # killed; attacked; triggered
		my $ev_obj_a  = $6; # kill:victim; action:actionname
		my $ev_obj_b  = $10; # kill:weapon; action:victim
		if (like($ev_verb, "killed") || like($ev_verb, "was incapped by")) {
			# players are $ev_player and $ev_obj_b
			addPlayer($ev_player);
			addPlayer($ev_obj_b);
		} elsif (like($ev_verb, "triggered")) {
			# players are $ev_player and $ev_obj_b
			addPlayer($ev_player);
			addPlayer($ev_obj_b);
		} elsif (like($ev_verb, "triggered a")) {
			# player is just $ev_player
			addPlayer($ev_player);
		}
		
	} elsif ($line =~ /^"(.+?(?:<.+?>)*?(?:|<setpos_exact ((?:|-)\d+?\.\d\d) ((?:|-)\d+?\.\d\d) ((?:|-)\d+?\.\d\d);.*?))" ([^"\(]+) "(.+?)"(.*)$/) {
		# player a did something
		my $ev_player = $1;
		my $uniqueid = addPlayer($ev_player);
		my $ev_verb   = $5;

	} elsif ($line =~ /^(?:Kick: |)"(.+?(?:<.+?>)*)" ([^\(]+)(.*)$/) {
		# player a did something (entered game, disconnected)
		my $ev_player = $1;
		my $ev_verb   = $2;
		my $uniqueid = addPlayer($ev_player);
		if(like($ev_verb, "disconnected") || like($ev_verb, "was kicked")) {
			delete($players{$uniqueid});
		}
	}
	
		
}

sub rconResponse
{
	my ($rcon_str) = @_;
	my $response;
	
	my ($cmd, $args) = split(/ +/, $rcon_str, 2);
	
	if(!$cmd) {
		return "";
	}
	
	if($cmd eq "status") {
		my $player_count = %players;
		$response = "hostname: ".$server_status{hostname}."\n"
			."version : 1.0.6.6/".$server_status{netver}." 3950 secure\n"
			."udp/ip  : 127.0.0.1:".$server_status{port}."\n"
			."map     : ".$server_status{mapname}." at 0 x, 0 y, 0 z\n"
			."players : ".$player_count." (".$server_status{maxplayers}." max)\n"
			."# userid name uniqueid connected ping loss state adr\n";
		my $player_key;
		foreach $player_key (keys(%players)) {
			my %player = %{$players{$player_key}};
			$response .= "# ".$player{"userid"}." \"".$player{"name"}."\" ".$player{"steamid"}." "
				.$player{"connected"}." 50 0 ".$player{"state"}." ".$player{"addr"}."\n";
		}
	} elsif ($cmd eq "log") {
		if(!$args || !length($args)) {
			$response = "Usage:  log < on | off >\ncurrently logging to: file, console, udp";

		}
	} elsif($cmd eq "logaddress_add") {
		my($host, $port);
		if($args =~ /"?([.\d]+):(\d+)"?/) {
			$host = $1;
			$port = $2; #) = split(/:/,$args,2);
		}
		if(!$log_clients{"$host:$port"}) {
			print("Trying to bind to log address $host:$port\n");
			my $log_client_sock = IO::Socket::INET->new (
				PeerPort => $port,
				PeerAddr => $host,
				LocalPort => $server_status{port},
				Proto => "udp",
				Reuse=>1 ,
				#ReusePort => 1,
				
			) or print("Can't bind new client socket!\nErr: $!\nVals: $host and $port\n");
			if($log_client_sock) {
				$log_clients{"$host:$port"} = $log_client_sock;
				$response = "logaddress_add:  $args\n";
			}
			foreach $log_client_sock (values(%log_clients)) {
				print $log_client_sock,"\n";
			}			
		} else {
			$response = "logaddress_add: $host:$port is already in the list.\n";
		}	

	} elsif($cmd eq "logaddress_del") {
		my ($host, $port);
		if($args =~ /"?([.\d]+):(\d+)"?/) {
			$host = $1;
			$port = $2; #) = split(/:/,$args,2);
		}
		if($log_clients{"$host:$port"}) {
			close($log_clients{"$host:$port"});
			delete($log_clients{"$host:$port"});
		}
		
		$response = "logaddress_del:  $args\n";
	} elsif(like($cmd, "stats")) {
		my $player_count = %players;
		$response = "CPU   In    Out   Uptime  Users   FPS    Players\n".
			"0.0 0.0 0.0 100 2 30.00 $player_count\n";
	} else {
		$response = "(Unknown/unhandled RCON request!)\n";
	}
	
	return $response;

}


##################### Main Program #####################
print "Starting up server on port $server_status{port}\n";
# Setting up the UDP port to listen on.
my $udp_socket = IO::Socket::INET->new (
	LocalPort       => $server_status{port},
	Proto           => "udp",
	#ReusePort => 1,
	Reuse => 1,
) or die "Can't create UDP server socket: $@";

my $tcp_socket = IO::Socket::INET->new (
	LocalPort       => $server_status{port},
	Proto           => "tcp",
	Listen => 1,
	Reuse => 1,
) or die "Can't create TCP server socket: $@";

my $read_set = new IO::Select();
$read_set->add($udp_socket);
$read_set->add($tcp_socket);

if(!$logfile_name) {
	die("Please specify a logfile to open!\n");
}
my $logfile;
open($logfile, "<", $logfile_name) or die("Can't open $logfile_name for reading!\n");

buildInitialPlayers($logfile);

{
print("Trying to establish connection to daemon: $daemon_host:$daemon_port\n");
my $log_client_sock = IO::Socket::INET->new (
	PeerPort => $daemon_port,
	PeerAddr => $daemon_host,
	LocalPort => $server_status{port},
	Proto => "udp",
	Reuse=>1 ,
	#ReusePort => 1,
) or die("Can't bind daemon log socket!");
$log_clients{"$daemon_host:$daemon_port"} = $log_client_sock;
}

my $line_count = 0;
print "Starting to accept messages\n";
while (1) {
	my @ready_set = $read_set->can_read($logline_delay);
	my $sock_count = @ready_set;
	if($sock_count == 0) {
		my $logline;
		my $client_count = %log_clients;
		if($logfile && $client_count) {
			$logline = <$logfile>;
			if(!$logline) {
				close($logfile);
				$logfile = undef;
				print("Ran out of log messages.\n");
			} else {
				my $timestamp = getTimeStamp();
				$logline =~ s/^(?:.*?)?L (\d\d)\/(\d\d)\/(\d{4}) - (\d\d):(\d\d):(\d\d):\s*//;
				parseLogLine($logline);
				my $log_response = pack("lZ*",-1,"RL ".$timestamp.": ".$logline);
				my $log_client_sock;
				foreach $log_client_sock (values(%log_clients)) {
					$log_client_sock->send($log_response);
				}
				$line_count = $line_count + 1;
				if($line_count % 500 == 0) {
					print("Log: $line_count lines transmitted\n");
				}
			}
		}
		
	}
	foreach my $socket (@ready_set) {
		my $response;
		if($socket == $tcp_socket) {
			# new TCP connection request
			print "Accepting new RCON connection from client.\n";
			my $tcp_client_sock = $socket->accept();
			$read_set->add($tcp_client_sock);
			print "Negotiated new client connection.\n";
		} elsif ($socket == $udp_socket) {
			# one of the source engine queries, handled via UDP
			my $msg;
			$socket->recv($msg,4096);
	
			my $len = unpack("l", $msg);
			# UDP Query of server status
			if ($len ==-1) { 
				my($junk, $type, $challenge) = unpack("lCl", $msg);
				if($type == 0x54) {
					print "Sending Source Engine Query reply to " . $socket->peerhost . ":" . $socket->peerport . "\n";
					&replyStatus($socket, %server_status);
				} elsif ($type == 0x57) {
					# challenge request
					$response = pack("lCl",-1,0x41,0);
					$socket->send($response);
				} elsif($type == 0x56) {
					# rules
					if($challenge == -1) {
						$response = pack("lCl",-1,0x41,0);
						$socket->send($response);
					} else {
						$response = pack("lCC",-1,0x45,0);
						$socket->send($response);
					}
				} elsif($type == 0x55) {
					# players
					if($challenge == -1) {
						$response = pack("lCl",-1,0x41,0);
						$socket->send($response);
					} else {
						$response = pack("lCC",-1,0x44,0);
						$socket->send($response);
					}					
				} else {
					print "Unimplemented UDP query recv'd: $type\n";
				}
			} else {
				print "$msg";
			}
		} else {
			# one of the temporary RCON sockets has data
			print "Getting data from temp. RCON socket\n";
			my ($size, $msg);
			$socket->recv($msg, 4);
			if($msg) {
				my ($size) = unpack("l", $msg);
				undef $msg;
				if($size && ($size > 0)) {
					$socket->recv($msg, $size);
				}
			}
			
			if($msg) {
				my($id, $reqtype, $cmd) = unpack("llZ*x", $msg);
				if($reqtype == 3) {
					# Client requesting authorization
					print "Client requests RCON access.\n";
					$response = pack("lllxx",10,$id,2);
					$socket->send($response);
				} else {
					print "Client sends RCON command: $cmd\n";
					my $remotehost = $socket->peerhost();
					my $remoteport = $socket->peerport();
					my $rcon_result = rconResponse($cmd);
					# the packet length includes 8 bytes for the ID and the type,
					# plus the length of the string and two null bytes
					if($rcon_result) {
						my $packet_length = 10+length($rcon_result);
						$response = pack("lllZ*x",$packet_length, $id, 0, $rcon_result);
						$socket->send($response);
					}
					foreach my $log_client_sock (values(%log_clients)) {
						print("sending RCON log data to $log_client_sock\n");
						my $curtime = getTimeStamp();
						my $log_packet = pack("lZ*", -1, "RL $curtime: rcon from \"$remotehost:$remoteport\": command \"$cmd\"\n");
						$log_client_sock->send($log_packet);
					}
					#$read_set->remove($socket);
					#close($socket);
				}
			} else {
				# actually, the socket's done.
				$read_set->remove($socket);
				close($socket);
				print "Client has closed RCON connection.\n";
			}
		}
	}
	
}
