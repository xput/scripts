#!/usr/bin/perl

# Version 0.3
# Postfix Admin version 740

#use strict;
#use warnings;
use CDB_File;
use Crypt::PasswdMD5;

# Paths and configuration
$virtualdomains = '/etc/qmail/virtualdomains';

$sysdomain      = 'xxx';

$postfixdb            = 'postfix';
$admin_table          = 'admin';
$domain_admins_table  = 'domain_admins';
$domain_table         = 'domain';
$alias_table          = 'alias';
$mailbox_table        = 'mailbox';

# Default settings
$defaultaliases   = '0';
$defaultmailboxes = '0';
$defaultmaxquota  = '0';
$defaultquota     = '0';
$defaulttransport = 'virtual';
$defaultvirusscan = '1';
$defaultspamscan  = '1';
$defaultbackupmx  = '0';
$defaultactive    = '1';
$defaultcreated   = 'NOW()';
$defaultmodified  = 'NOW()';

# Read domain definitions
open(VIRTUALDOMAINS, "<$virtualdomains") || die "File not found";
my @lines = <VIRTUALDOMAINS>;
close(VIRTUALDOMAINS);

# Build hash user => array(domains...)
my %domains; 
foreach $line (@lines) {
  chomp($line);
  ($domain,$user) = split(/:/, $line);
  push(@{$domains{$user}},$domain);
}

# Output header
print "########################################################################\n";
print "#\n";
print "# SQL data for Postfix\n";
print "#\n";
print "# created: ".localtime(time)."\n";
print "#\n";
print "USE $postfixdb;\n";
print "#\n";
print "# Truncate tables\n";
print "TRUNCATE TABLE `admin`;\n";
print "TRUNCATE TABLE `domain_admins`;\n";
print "TRUNCATE TABLE `domain`;\n";
print "TRUNCATE TABLE `alias`;\n";
print "TRUNCATE TABLE `mailbox`;\n";
print "#\n";

@users = sort keys %domains;

# Process each user with associated domains
foreach $user (@users) {
  # Determine default domain
  $l=@{$domains{$user}};
  for($i=0; $i<$l; $i++) {  
    if(@{$domains{$user}}[$i] =~ /$user/) {
      $defaultdomain = @{$domains{$user}}[$i];
      last;
    } else {
      $defaultdomain = @{$domains{$user}}[0];
    }
  }

  # Read user data
  open(PASSWD, "/etc/passwd") || die $!;
  @userlines = grep(/^$user:/,<PASSWD>);
  close(PASSWD);

  foreach $userline (@userlines) {
    ($login, $passwd, $uid, $gid, $comment, $home, $shell) = split(/:/,$userline);
    last; # should be only one
  }

  # Generate password
  $salt = &gen_string(8);
  $clearadminpass = &gen_string(8);
  $cryptadminpass = unix_md5_crypt($clearadminpass, $salt);
  $admin = $defaultdomain;

  # Begin output
  print "--------------------------------------------------------------------------------\n";
  print "--\n";
  print "-- User:             $user\n";
  print "-- Default domain:   $defaultdomain\n";
  print "-- Admin:            $admin\n";
  print "-- Password:         $clearadminpass ($cryptadminpass)\n";
  print "--\n";
  print "-- Domains:\n";
  foreach $domain (@{$domains{$user}}) {
    print "--  -> $domain\n";
  }
  print "#\n";
  print "# Insert admin entry:\n";
  print "INSERT INTO `$admin_table` VALUES ('$admin','$cryptadminpass',NOW(),NOW(),1);\n";
  foreach $domain (@{$domains{$user}}) {
    print "INSERT INTO `$domain_admins_table` VALUES ('$admin','$domain',NOW(),1);\n";
  }
  print "#\n";
  print "# Insert domains:\n";
  foreach $domain (@{$domains{$user}}) {
    print "INSERT INTO `$domain_table` VALUES ('$domain','$domain','$defaultaliases','$defaultmailboxes','$defaultmaxquota','$defaultquota','$defaulttransport','$defaultbackupmx','$defaultcreated','$defaultmodified','$defaultactive');\n";
    if($domain ne $defaultdomain) {
      print "INSERT INTO `$alias_table` VALUES ('\@$domain', '\@$defaultdomain', '$domain', '$defaultcreated', '$defaultmodified', '$defaultactive');\n"; 
    }
    print "#\n";
  }

  # Check if mailbox should be created
  $cdb = $home."/passwd.cdb";
  if ( -f $cdb ) {
    print "-- CDB file found ($cdb)\n";
    print "## Starting alias/mailbox processing\n";
    print "#\n";

    my %data;
    tie %data, 'CDB_File', $cdb || die "$0: can't tie to $cdb $!\n";

    while ((my $k, my $v) = each %data) {
      my $user = $k;
      # Catchall
      if($user eq "+") {$user = '*';}

      # Determine if account is active (hidden in 3rd byte)
      if (substr($v, 2, 1) =~ /\x1/) { $active = 1;} else {$active = 0;}

      # Remove status bytes
      my $data = substr($v, 4);

      # Split data by null bytes
      @data = split(/\x0/, $data);

      # First fields: password and maildir
      my $pass = shift(@data);
      my $maildir = shift(@data);

      # Then come forwarders
      my $entry=shift(@data);
      my $forwarder;
      while($entry ne "" ) {
        if($entry =~ /\@$/) { $entry = $entry.$sysdomain;}
        if(not($entry =~ /\@/)) { $entry = $entry."@".$defaultdomain;}
        if ($forwarder ne "") {$entry = ','.$entry;} 
        $forwarder .= $entry;
        $entry=shift(@data);
      }  

      my $name = shift(@data);
      if($name eq ''){$name = $user;}
      my $hardquota = shift(@data);
      if($hardquota eq '-'){$hardquota = '0';}
      my $softquota = shift(@data);
      if($softquota eq '-'){$softquota = '0';}
      my $messagesize = shift(@data);
      if($messagesize eq '-'){$messagesize = '0';}
      my $messagecount = shift(@data);
      if($messagecount eq '-'){$messagecount = '0';}
      my $created = shift(@data);
      my $valid = shift(@data);
      if($valid eq '-'){$valid = '0';}

      print "-- [$user] $name|$pass|$maildir|$forwarder\n";

      if ($maildir eq "" and $forwarder ne '') {
        print "INSERT INTO `$alias_table` VALUES ('$user\@$defaultdomain', '$forwarder', '$defaultdomain', '$defaultcreated','$defaultmodified', '$active');\n";
      } else {
        if ($forwarder ne '') {
          $forwarder = $user."\@".$defaultdomain.",".$forwarder; 
        } else {
          $forwarder = $user."\@".$defaultdomain;
        }

        print "INSERT INTO `$alias_table` VALUES ('$user\@$defaultdomain', '$forwarder', '$defaultdomain', '$defaultcreated', '$defaultmodified', '$active');\n";
        print "INSERT INTO `$mailbox_table` VALUES ('$user\@$defaultdomain', '$pass', '$name', '$defaultdomain/$user/', '$hardquota', '$user', '$defaultdomain', '$defaultcreated','$defaultmodified', '$active');\n";
      }

      print "#\n";
    }
  } else {
    print "-- No CDB file found ($cdb)\n";
    print "## Skipping alias/mailbox processing\n";
  }
  print "--------------------------------------------------------------------------------\n";
}

print "# DONE";

exit 0;

# Generate random string
sub gen_string {
  srand;
  my $l = shift;
  my @z = (0..9, 'a'..'z', 'A'..'Z');
  return join ("", @z[map{rand @z}(1 .. $l)]);
}
