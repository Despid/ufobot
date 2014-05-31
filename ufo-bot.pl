#!/usr/bin/env perl

###############################################################
# usage:
#    	$ ./ufo-bot irc.server.net 6667 #channel
#
###############################################################
# Master Commands:
# raw		+
#
#
# 
# Client commands:
#
#
#
# 
# 
# Auto commands:
#
#
# 
#
###############################################################

use strict;
use warnings;

use POSIX;
use threads;
use IO::Socket::INET;
use XML::Simple;
use LWP::Simple qw($ua getstore get);

$ua->timeout(5);

my (
$socket, 
$socks_proxy_enable, 
$socks_addr, 
$socks_port, 
$master_nick, 
$master_ident, 
$irc_addr, 
$irc_port, 
$ufo_version, 
$ufo_nick, 
$ufo_ident, 
$ufo_name, 
$ufo_prefix, 
$buf_size,
$rss_enabled,
);

my (
@irc_channels,
@rss_feeds,
) = ();

# "$debug = 1" will print irc server buffer to the console
my $debug = 1;	


# random quote from "quote.cfg"
###srand; my $quote;
#open FILE, "<quote.cfg" or die "[-] Could not open filename: $!\n";
##rand($.)<1 and ($quote=$_) while <FILE>;
#close FILE;
#$quote =~ s/[\r\n]+//g;

&read_init();

#read init.cfg
sub read_init() {
	open FILE, "<init.cfg" or die "[-] Could not open filename: $!\n";
	foreach my $line (<FILE>) {
		if ($debug == 1) { print $line };
		if ($line =~ m/^irc_addr=(.+)/) { $irc_addr = $1; }
		if ($line =~ m/^irc_port=(\d+)/) { $irc_port = $1; }
		if ($line =~ m/^socks_proxy_enable=(.+)/) { $socks_proxy_enable = $1; }
		if ($line =~ m/^socks_addr=(.+)/) { $socks_addr = $1; }
		if ($line =~ m/^socks_port=(.+)/) { $socks_port = $1; }
		if ($line =~ m/^master_nick=(.+)/) { $master_nick = $1; }
		if ($line =~ m/^master_ident=(.+)/) { $master_ident = $1; }
		if ($line =~ m/^ufo_version=(.+)/) { $ufo_version = $1; }
		if ($line =~ m/^ufo_nick=(.+)/) { $ufo_nick = $1; }
		if ($line =~ m/^ufo_ident=(.+)/) { $ufo_ident = $1; }
		if ($line =~ m/^ufo_name=(.+)/) { $ufo_name = $1; }
		if ($line =~ m/^ufo_prefix=(.+)/) { $ufo_prefix = $1; }
		if ($line =~ m/^buf_size=(\d+)/) { $buf_size = $1; }
		if ($line =~ m/^rss_enabled=(.+)/) { $rss_enabled = $1; }
		if ($line =~ m/^channels=(.+)/) { @irc_channels = split(/,/, $1); }
		if ($line =~ m/^rss_feeds=(.+)/) { @rss_feeds = split(/@@@@/, $1); }

	}

	close FILE;
}


# spawn socket
if ($socks_proxy_enable eq "no") {
	$socket = new IO::Socket::INET (
			PeerAddr => $irc_addr,
	        	PeerPort => $irc_port,
			Proto    => 'tcp',
			Timeout => 5,
	) or die "[-] $!";
} elsif ($socks_proxy_enable eq "yes") {
	##socks4code
	## $socket = new IO::Socket:Socks......
	##
}




#sub ctcp_version() {
#		$socket->syswrite("PRIVMSG $1 \001VERSION $ufo_version\001\r\n");
## @?????}


sub rss_update() {
	my @rss_threads;
	foreach (@rss_feeds) {
		push @rss_threads, threads->new(
			sub {
				if ($debug == 1){ print "**Fetching RSS $_ ...\n" }
				our $rss = get($_) or warn $!;

				our ( $xml, $i ) = ( XMLin( $rss ), 0 );

			        for ( $i=0; $i<5; $i++ ) {
					our $title = "$xml->{channel}->{item}->[$i]->{title}";
					our $description = "$xml->{channel}->{item}->[$i]->{description}";

					print "$title\n$description\n";			

				}
				
			}
		);
	}

	foreach (@rss_threads) {
		$_->join;
	}
}


##if ($rss_enabled eq "yes") { &rss_update; }


# register with ircd
while($socket->sysread(my $buf, $buf_size)) {
	if ($debug == 1) { print $buf . "\n";}

	$socket->syswrite("NICK $ufo_nick\r\n");
        $socket->syswrite("USER $ufo_ident 0 0 :$ufo_name\r\n");

        if ($buf =~ m/^:(.+)!(.+)@(.+)\ PRIVMSG\ (.+)\ :\001VERSION\001/) {
			$socket->syswrite("PRIVMSG $1 \001VERSION $ufo_version\001\r\n");
	}

       	last;
}

# join channels
while($socket->sysread(my $buf, $buf_size)) {
        if ($buf =~ m/^PING (:[^ ]+)$/i) { $socket->syswrite("PONG :$1\r\n" ) ;}
	if ($buf =~ m/(376|422)/i) { 
		foreach	my $channel (@irc_channels) {
			$socket->syswrite("JOIN $channel\r\n"); 
		}
		last;
	}
	if ($debug == 1) { print $buf . "\n";}
}


# listen
print "CONNECTED->$ufo_nick [$irc_addr:$irc_port]\n";
while($socket->sysread(my $buf, $buf_size)) {


	if ($debug == 1) { print $buf . "\n";}

	#### master ####
	#RAW
	if ($buf =~ m/^:$master_nick!$master_ident@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}raw\ (.+)/) 
	{
	                $socket->syswrite("$3\r\n");
        }
	#JOIN
	if ($buf =~ m/^:$master_nick!$master_ident@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}join\ (.+)/) 
	{
	                $socket->syswrite("JOIN $3\r\n");
        }
	#PART
	if ($buf =~ m/^:$master_nick!$master_ident@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}part\ (.+)/) 
	{
	                $socket->syswrite("PART $3\r\n");
        }
	#NOTICE
	if ($buf =~ m/^:$master_nick!$master_ident@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}notice\ (.+)/) 
	{
	                $socket->syswrite("NOTICE $3\r\n");
        }
	#MSG
	if ($buf =~ m/^:$master_nick!$master_ident@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}msg\ (.+)/) 
	{
	                $socket->syswrite("PRIVMSG $3\r\n");
        }
	#RSS FORCE UPDATE
	if ($buf =~ m/^:$master_nick!$master_ident@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}rss update/) 
	{
		if ($rss_enabled eq "yes") { 
	                $socket->syswrite("PRIVMSG $2 Updating rss cache...\r\n");
			&rss_update;
	                $socket->syswrite("PRIVMSG $2 Done.\r\n");
		} else {
	                $socket->syswrite("PRIVMSG $2 Error: rss_enabled set to \"no\" in (init.cfg)\r\n");
		}

        }
	#QUIT
	if ($buf =~ m/^:$master_nick!$master_ident@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}quit\ (.+)/) 
	{
	                $socket->syswrite("QUIT $3\r\n");
        }



	#### client ####
	#help
	if ($buf =~ m/^:(.+)!(.+)@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}help/) 
	{
	                $socket->syswrite("NOTICE $1 [help options][commands, master, info]\r\n");
        }
	#help commands
	if ($buf =~ m/^:(.+)!(.+)@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}help\ commands/) 
	{
	                $socket->syswrite("NOTICE $1 [command options][!slap <nick> <object>, !kick <nick> <msg>, !curse <nick>\r\n");
        }
	#help master
	if ($buf =~ m/^:$master_nick!$master_ident@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}help\ master/) 
	{
	                $socket->syswrite("NOTICE $1 [master options][!raw, !join, !part, !notice, !msg, !quit\r\n");
	}
	#help info
	if ($buf =~ m/^:(.+)!(.+)@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}help\ info/) 
	{
	                $socket->syswrite("NOTICE $1 [info][$ufo_version by unixfreak][a useless irc bot]\r\n");
        }


	#CURSE
	if ($buf =~ m/^:(.+)!(.+)@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}curse\ (.+)/) 
	{
	                $socket->syswrite("PRIVMSG $4 $5  - this is a fucking test\r\n");
        }
	#SLAP
	if ($buf =~ m/^:(.+)!(.+)@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}slap\ (.+)\ (.+)/) 
	{
	                $socket->syswrite("PRIVMSG $4 $ufo_nick slaps $5 with a $6\r\n");
        }
	#STATS
	if ($buf =~ m/^:(.+)!(.+)@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}stats/) 
	{
	                $socket->syswrite("PRIVMSG $4 I am currently on @irc_channels channels and i can see null users.\r\n");
        }
	
	#WHOIS  (TODO/broken)
	#if ($buf =~ m/^:(.+)!(.+)@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}whois\ (.+)/) 
	#{
	#
	#	our $channel = $4;
	#                $socket->syswrite("WHOIS $5\r\n");
	#		$socket->sysread(our $buf, $buf_size);
	#		if ($buf =~ /^:(.+)\ 311\ $ufo_nick\ (.+)/) {
	#	                $socket->syswrite("PRIVMSG $channel test $2\r\n");			
	#		}
	#		$socket->sysread(our $buf, $buf_size);
	#		if ($buf =~ /^:(.+)\ 319\ $ufo_nick\ (.+)/) {
	#	                $socket->syswrite("PRIVMSG $channel test $2\r\n");			
	#		}
	#		$socket->sysread(our $buf, $buf_size);
	#		if ($buf =~ /^:(.+)\ 317\ $ufo_nick\ (.+)/) {
	#	                $socket->syswrite("PRIVMSG $channel test $2\r\n");				
	#		}
        #}
	
	#NAMES  (TODO/broken)
	#if ($buf =~ m/^:(.+)!(.+)@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}users/) 
	#{
	#	our $channel = $4;
	#
	#		$socket->syswrite("NAMES\r\n");
	#	        our $result = $buf;
	#	
	#                $socket->syswrite("PRIVMSG $4 There are $result users in $channel\r\n");
        #}



	#### connection #####

	#PING handler
        if ($buf =~ m/^PING (:[^ ]+)$/i) {
                $socket->syswrite("PONG :$1\r\n");
        }

	#CTCP handler
        if ($buf =~ m/^:(.+)!(.+)@(.+)\ PRIVMSG\ (.+)\ :\001VERSION\001/) {
		$socket->syswrite("PRIVMSG $1 \001VERSION $ufo_version\001\r\n");

        }



}
print "DISCONNECT->$ufo_nick [$irc_addr:$irc_port]\n";


