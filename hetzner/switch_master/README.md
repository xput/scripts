Hetzner Failover-IP Management Script
=====================================

This Perl script manages a Hetzner Failover IP between two servers. It checks the reachability of a master server and can automatically or manually switch to a slave server in case of failure.

Features
--------

- Automatic switch-over if the master is unreachable
- Manual failover with `--force`
- Display current status with `--info`
- Uses Hetzner Robot Webservice API
- Prevents multiple simultaneous script executions

Requirements
------------

Install the following Perl modules before using the script (via `cpan` or `apt`):

    cpan install JSON LWP::UserAgent MIME::Base64 Net::Ping Fcntl Getopt::Long

Or on Debian/Ubuntu:

    sudo apt install libjson-perl libwww-perl libnet-ping-perl

Required Environment Variables
------------------------------

The following environment variables must be set before running the script:

| Variable         | Description                          |
|------------------|--------------------------------------|
| API_USER         | Hetzner API username                 |
| API_PASS         | Hetzner API password                 |
| IP_INTERNAL      | Internal tunnel IP of the master     |
| IP_VIRTUAL       | Failover IP                          |
| IP_SERVER_A      | IP address of Server A               |
| NAME_SERVER_A    | Label or name of Server A            |
| IP_SERVER_B      | IP address of Server B               |
| NAME_SERVER_B    | Label or name of Server B            |

Example:

    export API_USER="robot_user"
    export API_PASS="supersecret"
    export IP_INTERNAL="10.0.0.1"
    export IP_VIRTUAL="192.0.2.1"
    export IP_SERVER_A="203.0.113.10"
    export NAME_SERVER_A="server-a"
    export IP_SERVER_B="203.0.113.20"
    export NAME_SERVER_B="server-b"

Usage
-----

Show current status:

    perl failover.pl --info

Force failover (e.g., in emergency):

    perl failover.pl --force

Automatic mode (default execution with no arguments):

    perl failover.pl

- Checks whether the internal tunnel IP is reachable
- Optionally checks the virtual IP
- Automatically switches to the slave server if necessary

Notes
-----

- Communication with Hetzner API is done via HTTP Basic Auth.
- SSH access to the slave on port 22022 is required for switching.
- Only one script instance runs at a time (using `flock`).

Testing
-------

You can safely test the script in a sandbox environment using dummy IPs and mock data as long as you avoid executing real switching actions.

License
-------

MIT License
