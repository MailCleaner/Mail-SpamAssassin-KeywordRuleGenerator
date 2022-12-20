#!/usr/bin/perl

# Basic test to ensure files can be found and read. Verification will come later

use Test::More;

use lib 'lib/';
use Mail::SpamAssassin::KeywordRuleGenerator;

my $id = '05';

my $kw = Mail::SpamAssassin::KeywordRuleGenerator->new( { 'id' => T.$id, 'debug' => 0, 'joinScores' => 0 } );
my $testdir = $ENV{'PWD'}.'/t/'.T.$id;
ok (!$kw->createDir($testdir), "Created output directory: '$ENV{'PWD'}/t/$id'");
$kw->setDir($testdir);
ok ($kw->getDir() eq $testdir, "Set output directory: '$ENV{'PWD'}/t/$id'");

my @files = ( 't/04_rules0.cf', 't/04_rules1.cf' );
my @failed = @{$kw->readAll( @files )};
ok(!scalar(@failed), "Load 'rules' hash with readAll");

$kw->writeAll();

my @files = glob($testdir.'/*.cf');
ok (scalar(@files) == 6, "Correct number of files generated");
my %expected = (
        '50_T05_T_04_RULES0.cf' => 169,
        '50_T05_T_04_RULES0_SCORES.cf' => 105,
        '50_T05_T_04_RULES1.cf' => 148,
        '50_T05_T_04_RULES1_SCORES.cf' => 97,
        '51_T05.cf' => 60,
        '51_T05_SCORES.cf' => 90
);
my %remaining = %expected;
foreach (@files) {
        $e = $_;
        $e =~ s/^(.*\/)?t\/T05\///;
        if (open(my $fh, "<", $_)) {
                while (<$fh>) {
                        $expected{$e}--;
                }
                close($fh);
        }
        ok ($expected{$e} == 0, "Correct number of lines found in $e");
        delete($remaining{$e});
}
ok (!scalar(keys(%remaining)), "All expected output files found");

use Mail::SpamAssassin;
my $sa = Mail::SpamAssassin->new( { 'site_rules_filename' => $testdir } );
$failed = $sa->lint_rules();
ok (!$failed, "Verified by spamassassin".($res ? "\n$failed" : ""));

$kw->cleanDir();

done_testing();

