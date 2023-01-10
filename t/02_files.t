#!/usr/bin/perl

# Basic test to ensure files can be found and read. Verification will come later

use Test::More;

use lib 'lib/';
use Mail::SpamAssassin::KeywordRuleGenerator;

my $id = '02';

my $kw = Mail::SpamAssassin::KeywordRuleGenerator->new( { 'id' => $id } );

# Read a single file
my $file = 't/02_files.cf';
ok (!$kw->readFile($file), "Run readFile on $file");
ok ($kw->getFile($file) == $file, "Get current working file");
ok (scalar(keys(%{$kw->{'rules'}})) == 2, "Fetched correct number of files in rules");
ok ($kw->{'rules'}->{$file}, "Loaded correct hash key");
ok ($kw->{'filemap'}->{$file} =~ m/50_02_T_02_FILES.cf$/, "Loaded correct output name");
ok (!$kw->clearAll(), "Clear 'rules' hash");
ok (!scalar(keys(%{$kw->{'rules'}})), "Fetched none after clearing");

# Read a directory
my $dir = 't/02_files.dir';
ok (!$kw->readAll($dir), "Run file on dir");
ok (scalar(keys(%{$kw->{'rules'}})) == 3, "Fetched correct number of files from dir");
ok (!$kw->clearAll(), "Clear dir files");

# Read a symlink
my $link = 't/02_files.lnk';
ok (!$kw->readAll($link), "Run file on link");
ok ($kw->getFile() == $file, "Fetched correct name ($file) from link ($link)");
ok (scalar(keys(%{$kw->{'rules'}})) == 2, "Fetched correct number of files from link");
ok (!$kw->clearAll(), "Clear link files");

# Read multiple mixed
ok (!$kw->readAll($file, $dir, $link), "Run readAll on multiple/mixed");
ok (scalar(keys(%{$kw->{'rules'}})) == 5, "Fetched correct number of files from all");
ok (!$kw->clearAll(), "Clear dir files");


ok ($kw->readFile('does_not_exist'), "Correctly failed for non-existent file");
ok (!$kw->getFile(), "Current name undefined for non-existent file");
ok ($kw->readFile('t/02_unreadable.cf'), "Correctly failed for non-readable file");
ok (!$kw->getFile(), "Current name undefined for non-readable file");

done_testing();
