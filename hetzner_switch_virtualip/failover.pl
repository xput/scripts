#!/usr/bin/perl

use strict;
use warnings;
use v5.10;
use JSON;
use LWP::UserAgent;
use HTTP::Request::Common;
use MIME::Base64;
use Data::Dumper;
use Net::Ping;
use Fcntl qw(:flock);
use Getopt::Long;

#---------------------------#
#   Logging function
#---------------------------#
sub log_msg {
    my ($msg) = @_;
    my $ts = scalar localtime();
    print "[$ts] $msg\n";
}

#---------------------------#
#   Ensure only one instance
#---------------------------#
unless (flock(DATA, LOCK_EX|LOCK_NB)) {
    log_msg("$0 is already running. Exiting.");
    exit(1);
}

#---------------------------#
#   Get command-line options
#---------------------------#
my ($force, $info, $help);
GetOptions(
    'force' => \$force,
    'info'  => \$info,
    'help'  => \$help,
);

#---------------------------#
#   Validate ENV variables
#---------------------------#
for my $var (qw(API_USER API_PASS IP_INTERNAL IP_VIRTUAL IP_SERVER_A IP_SERVER_B NAME_SERVER_A NAME_SERVER_B)) {
    die "Missing environment variable: $var\n" unless $ENV{$var};
}

#---------------------------#
#   Config from ENV
#---------------------------#
my $url = 'https://robot-ws.your-server.de/failover';
my $user = $ENV{API_USER};
my $pass = $ENV{API_PASS};
my $ip_internal = $ENV{IP_INTERNAL};
my $ip_virtual  = $ENV{IP_VIRTUAL};
my $ip_server_a = $ENV{IP_SERVER_A};
my $ip_server_b = $ENV{IP_SERVER_B};
my $name_server_a = $ENV{NAME_SERVER_A};
my $name_server_b = $ENV{NAME_SERVER_B};
my ($primary, $primary_name, $secondary, $secondary_name);

#---------------------------#
#   Main logic
#---------------------------#
if ($help) {
    help();
} 
elsif ($info) {
    get_info();
    log_msg("virtual: $ip_virtual");
    log_msg("primary : $primary ($primary_name)");
    log_msg("secondary  : $secondary ($secondary_name)");
}
elsif ($force) {
    get_info();
    if (system("ssh -p22022 root\@$secondary service openvpn start") != 0) {
        log_msg("Error: Failed to start OpenVPN on $secondary");
        exit 5;
    }
    switch_to($secondary);
    log_msg("Switched to secondary: $secondary ($secondary_name)");
} 
else {
    if (ping_check($ip_internal)) {
        exit 0;
    } elsif (ping_check($ip_virtual)) {
        log_msg("Tunnel seems broken, not switching!");
        exit 2;
    } else {
        get_info();
        unless (ping_check($secondary)) {
            log_msg("Neither primary nor secondary is reachable!");
            exit 4;
        }
        if (system("ssh -p22022 root\@$secondary service openvpn start") != 0) {
            log_msg("Error: Failed to start OpenVPN on $secondary");
            exit 5;
        }
        switch_to($secondary);
        log_msg("Switched from $primary ($primary_name) to $secondary ($secondary_name)");
    }
}

#---------------------------#
#   Subroutines
#---------------------------#
sub get_info {
    my $ua = LWP::UserAgent->new;
    my $req = GET("$url/$ip_virtual");
    $req->authorization_basic($user, $pass);
    my $res = $ua->request($req);

    die "HTTP error: " . $res->code . " " . $res->message unless $res->is_success;

    my $data;
    eval {
        $data = decode_json($res->content);
        1;
    } or die "Failed to parse JSON response";

    $primary = $data->{failover}{active_server_ip};
    if ($ip_server_a ne $primary) {
        $secondary = $ip_server_a;
        $secondary_name = $name_server_a;
        $primary_name = $name_server_b;
    } elsif ($ip_server_b ne $primary) {
        $secondary = $ip_server_b;
        $secondary_name = $name_server_b;
        $primary_name = $name_server_a;
    } else {
        die "Unable to determine primary/secondary status";
    }
}

sub switch_to {
    my ($host) = @_;
    my $ua = LWP::UserAgent->new;
    my $req = POST("$url/$ip_virtual", [ active_server_ip => $host ]);
    $req->authorization_basic($user, $pass);

    my $res = $ua->request($req);
    die "HTTP error: " . $res->code . " " . $res->message unless $res->is_success;

    my $data = eval { decode_json($res->content) } 
        or die "Failed to parse JSON response";

    $primary = $data->{failover}{active_server_ip};
    if ($ip_server_a ne $primary) {
        $secondary = $ip_server_a;
        $secondary_name = $name_server_a;
        $primary_name = $name_server_b;
    } elsif ($ip_server_b ne $primary) {
        $secondary = $ip_server_b;
        $secondary_name = $name_server_b;
        $primary_name = $name_server_a;
    } else {
        die "Unable to determine new primary/secondary status";
    }
}

sub ping_check {
    my ($host) = @_;
    my $p = Net::Ping->new();
    my $success = 0;
    for (1..2) {
        $success++ if $p->ping($host, 4);
    }
    return $success;
}

sub help {
    print STDERR <<'USAGE';

Switch primary server on Hetzner failover IP.

Usage: failover.pl [options]

    -i --info     Show current status
    -f --force    Force switch to secondary
    -h --help     Display this help

USAGE
    exit;
}

__DATA__
