# vmailmgr to Postfix Admin Migration Script

This Perl script is designed to migrate a legacy `vmailmgr`-based Qmail setup to a modern Postfix Admin-compatible MySQL database structure.

## Features

- Reads domain mappings from `/etc/qmail/virtualdomains`
- Parses system users from `/etc/passwd`
- Extracts mail data from per-user `passwd.cdb` files
- Automatically generates:
  - SQL INSERTs for `admin`, `domain_admins`, `domain`, `alias`, and `mailbox` tables
  - Encrypted random admin passwords using MD5
  - Forwarding aliases and mailbox entries

## Requirements

- Perl 5
- Perl Modules:
  - `CDB_File`
  - `Crypt::PasswdMD5`
- Access to:
  - `/etc/qmail/virtualdomains`
  - `/etc/passwd`
  - Each user's `$HOME/passwd.cdb`

## Usage

```bash
perl vmailmgr_to_postfixadmin.pl > postfix_import.sql
