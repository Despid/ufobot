#!/usr/bin/env perl

###############################################################
# usage:
#    	$ ./ufo-bot.pl [/path/to/init.cfg]
#
# Master Commands:
#    <prefix>(raw|join|part|notice|msg|ctcp|quit|nick)
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
use IO::Socket::Socks;
use XML::Simple;
use LWP::Simple qw($ua getstore get);

$ua->timeout(5);

my (
$socket, 
$socks_proxy_enable, 
$socks_addr, 
$socks_port, 
$socks_timeout,
$master_nick, 
$master_ident, 
$irc_addr, 
$irc_port, 
$irc_timeout,
$ufo_version, 
$ufo_nick, 
$ufo_ident, 
$ufo_name, 
$ufo_prefix, 
$ufo_quitmsg,
$buf_size,
$rss_enabled,
);

my (
@irc_channels,
@rss_feeds,
) = ();

# "$debug = 1" will print irc server buffer to the console
my ($initfile, $debug) = ("init.cfg", 1);	



if (!@ARGV < 1) {$initfile =$ARGV[0];}
&read_init();

#read init.cfg
sub read_init() {
	open FILE, "<$initfile" or die "[-] Could not open filename: $!\n";
	foreach my $line (<FILE>) {
		if ($debug == 1) { print $line };
		if ($line =~ m/^irc_addr=(.+)/) { $irc_addr = $1; }
		if ($line =~ m/^irc_port=(\d+)/) { $irc_port = $1; }
		if ($line =~ m/^irc_timeout=(\d+)/) { $irc_timeout = $1; }
		if ($line =~ m/^socks_proxy_enable=(.+)/) { $socks_proxy_enable = $1; }
		if ($line =~ m/^socks_addr=(.+)/) { $socks_addr = $1; }
		if ($line =~ m/^socks_port=(.+)/) { $socks_port = $1; }
		if ($line =~ m/^socks_timeout=(\d+)/) { $socks_timeout = $1; }
		if ($line =~ m/^master_nick=(.+)/) { $master_nick = $1; }
		if ($line =~ m/^master_ident=(.+)/) { $master_ident = $1; }
		if ($line =~ m/^ufo_version=(.+)/) { $ufo_version = $1; }
		if ($line =~ m/^ufo_nick=(.+)/) { $ufo_nick = $1; }
		if ($line =~ m/^ufo_ident=(.+)/) { $ufo_ident = $1; }
		if ($line =~ m/^ufo_name=(.+)/) { $ufo_name = $1; }
		if ($line =~ m/^ufo_prefix=(.+)/) { $ufo_prefix = $1; }
		if ($line =~ m/^ufo_quitmsg=(.+)/) { $ufo_quitmsg = $1; }
		if ($line =~ m/^buf_size=(\d+)/) { $buf_size = $1; }
		if ($line =~ m/^rss_enabled=(.+)/) { $rss_enabled = $1; }
		if ($line =~ m/^irc_channels=(.+)/) { @irc_channels = split(/,/, $1); }
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
			Timeout => $irc_timeout,
	) or die "[-] $!";
} elsif ($socks_proxy_enable eq "yes") {
	$socket = new IO::Socket::Socks(
        	        ProxyAddr=>$socks_addr,
	                ProxyPort=>$socks_port,
	                ConnectAddr=>$irc_addr,
	                ConnectPort=>$irc_port,
	                SocksDebug=>0,
	                Timeout => $socks_timeout,
	                SocksVersion => 4,
	) or die "[-] $SOCKS_ERROR";
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

# autojoin
while($socket->sysread(my $buf, $buf_size)) {
        if ($buf =~ m/^PING (:[^ ]+)$/i) { $socket->syswrite("PONG :$1\r\n" ) ;}
	if ($buf =~ m/(376|422)/i) { 
		#$socket->syswrite("\r\n");
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

	#### master
	###### server commands
	if ($buf =~ m/^:$master_nick!$master_ident@(.+)\ PRIVMSG\ (.+)\ :${ufo_prefix}(raw|join|part|notice|msg|ctcp|quit|nick)\ (.+)/) 
	{
		if    ($3 eq 'raw'	) { $socket->syswrite("$4\r\n");}
		elsif ($3 eq 'join'	) { $socket->syswrite("JOIN $4\r\n");}
		elsif ($3 eq 'part'	) { $socket->syswrite("PART $4\r\n");}
		elsif ($3 eq 'notice'	) { $socket->syswrite("NOTICE $4\r\n");}
		elsif ($3 eq 'msg'	) { $socket->syswrite("PRIVMSG $4\r\n");}
		#elsif ($3 eq 'ctcp'	) { ##goto sub here##   $socket->syswrite(" $3\r\n");}
		elsif ($3 eq 'quit'	) { $socket->syswrite("QUIT $4\r\n");}
		elsif ($3 eq 'nick'	) { $socket->syswrite("NICK $4\r\n");}
		
        }

	if ($buf =~ m/^:(.+)!(.+)@(.+)\ PRIVMSG\ (.+)\ :\001VERSION\001/) {
                $socket->syswrite("PRIVMSG $1 \001VERSION $ufo_version\001\r\n");

        }

	###### user commands
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



	#### client
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


# random quote from "quote.cfg"
###srand; my $quote;
#open FILE, "<quote.cfg" or die "[-] Could not open filename: $!\n";
##rand($.)<1 and ($quote=$_) while <FILE>;
#close FILE;
#$quote =~ s/[\r\n]+//g;
