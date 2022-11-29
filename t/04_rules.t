#!/usr/bin/perl

# Basic test to ensure files can be found and read. Verification will come later

use Test::More;

use lib 'lib/';
use Mail::SpamAssassin::KeywordRuleGenerator;

my $id = '04';

my $kw = Mail::SpamAssassin::KeywordRuleGenerator->new( { 'id' => $id, 'debug' => 0 } );

my @files = ( 't/04_rules0.cf', 't/04_rules1.cf' );
my @failed = @{$kw->readAll( @files )};
ok(!scalar(@failed), "Load 'rules' hash with readAll");

my $expected = getExpected();
my ( $missing, $extra, $incorrect ) = 0;
use Data::Dump;
foreach my $file (keys(%{$expected})) {
        if ($file eq 'GLOBAL') {
                my ($m, $e) = compareGroups(
                        $expected->{$file},
                        $kw->{'rules'}->{$file}
                );
                print("Missing $m words\n") if ($m);
                print("$e extra words\n") if ($e);
                $missing += $m;
                $extra += $e;
        } else {
                foreach my $group (keys(%{$expected->{$file}})) {
                        if ($group eq 'SCORED') {
                                my ($m, $e, $i) = compareScores(
                                        $expected->{$file}->{$group},
                                        $kw->{'rules'}->{$file}->{$group}
                                );
                                $missing += $m;
                                $extra += $e;
                                $incorrect += $i;
                        } elsif ($group eq 'COMMENTS') {
                                my ($m, $e, $i) = compareScores(
                                        $expected->{$file}->{$group},
                                        $kw->{'rules'}->{$file}->{$group}
                                );
                                $missing += $m;
                                $extra += $e;
                                $incorrect += $i;
                        } else {
                                my ($m, $e) = compareGroups(
                                        $expected->{$file}->{$group},
                                        $kw->{'rules'}->{$file}->{$group}
                                );
                                $missing += $m;
                                $extra += $e;
                        }
                }
        }
}

ok ($missing == 0, "No expected rules are missing");
ok ($extra == 0, "No extra rules are found");
ok ($incorrect == 0, "No incorrect scores are found");

done_testing();

sub compareGroups
{
        my $expect = shift;
        my $loaded = shift;

        my @e = sort(@{$expect}); 
        my @l = sort(@{$loaded}); 
        my ($missing, $extra) = (0, 0);

        while (scalar(@e)) {
                unless (scalar(@l)) {
                        print("extra words @l\n");
                        $extra += scalar(@e);
                        last;
                }
                if ($e[0] eq $l[0]) {
                        shift(@e);
                        shift(@l);
                        next();
                }
                if ($e[0] lt $l[0]) {
                        print("Extra word $e[0]\n");
                        $extra++;
                        shift(@e);
                        next;
                }
                if ($e[0] gt $l[0]) {
                        print("Missing word $l[0]\n");
                        $missing++;
                        shift(@l);
                        next;
                }
        }
        if (scalar(@e)) {
                print("Missing ".scalar(@e)." at the end of parsing\n");
                $missing += scalar(@e);
                last;
        }

        return ($missing, $extra);
}

sub compareScores
{
        my $expect = shift;
        my $loaded = shift;

        my %remaining = %{$loaded};
        my ($missing, $extra, $incorrect) = (0, 0, 0);
        foreach my $word (keys(%$expect)) {
                if (!defined($loaded->{$word})) {
                        print("Missing score assignment for $word\n");
                        $missing++;
                } elsif ($expect->{$word} != $loaded->{$word}) {
                        print("Incorrect score assignment for $word\n");
                        $incorrect++;
                } else {
                        delete($remaining{$word});
                }
        }
        $extra = scalar(keys(%remaining));
        print("Extra score assignment for $word\n") foreach (@{$extra});

        return ($missing, $extra, $incorrect);
}

sub getExpected
{
        my %expected = (
                'GLOBAL' => [
                        'lorem',
                        'ipsum',
                        'dolor',
                        'sit',
                        'amet',
                        'consectetur',
                        'adipiscing',
                        'elit',
                        'sed',
                        'do',
                        'eiusmod',
                        'tempor',
                        'minim',
                        'veniam',
                        'quis',
                        'nostrud',
                        'exercitation',
                        'ullamco',
                        'laboris',
                        'nisi',
                        'ut',
                        'aliquip',
                        'ex',
                        'ea',
                        'commodo',
                        'consequat',
                        'duis',
                        'dolore',
                        'eu',
                        'fugiat',
                ],
                '50_04_T_04_RULES0.cf' => {
                        'SCORED' => {
                                'lorem' => 1,
                                'sit' => 1,
                                'adipiscing' => 1,
                                'do' => 1,
                                'incididunt' => 1,
                                'et' => 1,
                                'aliqua' => 1,
                                'minim' => 1,
                        },
                        'COMMENTS' => {
                                'lorem' => '1, 1, 1, 1',
                                'ipsum' => '1, 1, 1, 0',
                                'dolor' => '1, 1, 1, undef',
                                'sit' => '1, 1, 0, 1',
                                'amet' => '1, 1, 0, 0',
                                'consectetur' => '1, 1, 0, undef',
                                'adipiscing' => '1, 0, 1, 1',
                                'elit' => '1, 0, 1, 0',
                                'sed' => '1, 0, 1, undef',
                                'do' => '1, 0, 0, 1',
                                'eiusmod' => '1, 0, 0, 0',
                                'tempor' => '1, 0, 0, undef',
                                'incididunt' => '0, 1, 1, 1',
                                'ut' => '0, 1, 1, 0',
                                'labore' => '0, 1, 1, undef',
                                'et' => '0, 1, 0, 1',
                                'dolore' => '0, 1, 0, 0',
                                'magna' => '0, 1, 0, undef',
                                'aliqua' => '0, 0, 1, 1',
                                'enim' => '0, 0, 1, 0',
                                'ad' => '0, 0, 1, undef',
                                'minim' => '0, 0, 0, 1',
                                'veniam' => '0, 0, 0, 0',
                                'quis' => '0, 0, 0, undef',
                        },
                        'LOCAL' => [
                                'lorem',
                                'ipsum',
                                'dolor',
                                'sit',
                                'amet',
                                'consectetur',
                                'incididunt',
                                'ut',
                                'labore',
                                'et',
                                'dolore',
                                'magna',
                                'minim',
                                'veniam',
                                'quis',
                        ],
                        'group' => [
                                'lorem',
                                'ipsum',
                                'dolor',
                                'adipiscing',
                                'elit',
                                'sed',
                                'incididunt',
                                'ut',
                                'labore',
                                'aliqua',
                                'enim',
                                'ad',
                        ]
                },
                '50_04_T_04_RULES1.cf' => {
                        'SCORED' => {
                                'nostrud' => 1,
                                'laboris' => 1,
                                'aliquip' => 1,
                                'consequat' => 1,
                                'aute' => 1,
                                'in' => 1,
                                'velit' => 1,
                                'dolore' => 1,
                        },
                        'LOCAL' => [
                                'nostrud',
                                'exercitation',
                                'ullamco',
                                'laboris',
                                'nisi',
                                'ut',
                                'aute',
                                'irure',
                                'dolor',
                                'in',
                                'reprehenderit',
                                'volupatate',
                                'dolore',
                                'eu',
                                'fugiat',
                        ],
                        'group' => [
                                'nostrud',
                                'exercitation',
                                'ullamco',
                                'aliquip',
                                'ex',
                                'ea',
                                'aute',
                                'irure',
                                'dolor',
                                'velit',
                                'esse',
                                'cillum',
                        ]
                }
        );

        return \%expected;
}
