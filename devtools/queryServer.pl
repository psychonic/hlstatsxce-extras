#!/usr/bin/perl

use strict;
use IO::Socket;

#l4d2.packhead.com:27050

my $address = "l4d2.packhead.com";
my $port = "27050";

sub queryServer
{
        my ($iaddr, $iport, @query)            = @_;
        my $game = "";
        my $timeout=2;
        my $message = IO::Socket::INET->new(Proto=>"udp",Timeout=>$timeout,PeerPort=>$iport,PeerAddr=>$iaddr) or die "Can't make UDP socket: $@";
        $message->send("\xFF\xFF\xFF\xFFTSource Engine Query\x00");
        my ($datagram,$flags);
        my $end = time + $timeout;
        my $rin = '';
        vec($rin, fileno($message), 1) = 1;

        my %hash = ();

        while (1) {
                my $timeleft = $end - time;
                last if ($timeleft <= 0);
                my ($nfound, $t) = select(my $rout = $rin, undef, undef, $timeleft);
                last if ($nfound == 0); # either timeout or end of file
                $message->recv($datagram,1024,$flags);
                @hash{qw/key type netver hostname mapname gamedir gamename id numplayers maxplayers numbots dedicated os passreq secure gamever edf port/} = unpack("LCCZ*Z*Z*Z*vCCCCCCCZ*Cv",$datagram);
        }

        return @hash{@query};
}

my @query = (
		'gamename',
		'gamedir',
		'hostname',
		'numplayers',
		'maxplayers',
		'mapname'
		);

my ($gamename, $gamedir, $hostname, $numplayers, $maxplayers, $mapname) = &queryServer($address, $port, @query);

print "gamename:   $gamename\n";
print "gamedir:    $gamedir\n";
print "hostname:   $hostname\n";
print "numplayers: $numplayers\n";
print "maxplayers: $maxplayers\n";
print "mapname:    $mapname\n";
