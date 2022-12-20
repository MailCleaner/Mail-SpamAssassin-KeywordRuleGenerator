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
                my ($m, $e) = compareValues(
                        $expected->{$file},
                        $kw->{'rules'}->{$file}
                );
                print("Missing $m words in GLOBAL\n") if ($m);
                print("$e extra words in GLOBAL\n") if ($e);
                $missing += $m;
                $extra += $e;
        } else {
                foreach my $group (keys(%{$expected->{$file}})) {
                        if ($group eq 'SCORED' || $group eq 'COMMENTS') {
                                my ($m, $e, $i) = compareValues(
                                        $expected->{$file}->{$group},
                                        $kw->{'rules'}->{$file}->{$group}
                                );
                                $missing += $m;
                                $extra += $e;
                                $incorrect += $i;
                        } else {
                                my ($m, $e) = compareLists(
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

sub compareLists
{
        my $expect = shift;
        my $loaded = shift;

        my @e = sort(@{$expect}); 
        my @l = sort(@{$loaded}); 
        my ($missing, $extra) = (0, 0);

        while (scalar(@e)) {
                unless (scalar(@l)) {
                        print("extra words @e\n");
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

sub compareValues
{
        my $expect = shift;
        my $loaded = shift;

        my %remaining = %{$loaded};
        my ($missing, $extra, $incorrect) = (0, 0, 0);
        foreach my $word (keys(%$expect)) {
                if (!defined($loaded->{$word}) && defined($expect->{$word}) && $expect->{$word} != 0) {
                        print("Missing value assignment for $word\n");
                        $missing++;
                } elsif ($expect->{$word} != $loaded->{$word}) {
                        print("Incorrect value assignment for $word\n");
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
                'GLOBAL' => {
                        'lorem' => 't/04_rules0.cf',
                        'ipsum' => 't/04_rules0.cf',
                        'dolor' => 't/04_rules0.cf',
                        'sit' => 't/04_rules0.cf',
                        'amet' => 't/04_rules0.cf',
                        'consectetur' => 't/04_rules0.cf',
                        'adipiscing' => 't/04_rules0.cf',
                        'elit' => 't/04_rules0.cf',
                        'sed' => 't/04_rules0.cf',
                        'do' => 't/04_rules0.cf',
                        'eiusmod' => 't/04_rules0.cf',
                        'tempor' => 't/04_rules0.cf',
                        'minim' => 't/04_rules0.cf',
                        'veniam' => 't/04_rules0.cf',
                        'quis' => 't/04_rules0.cf',
                        'nostrud' => 't/04_rules1.cf',
                        'exercitation' => 't/04_rules1.cf',
                        'ullamco' => 't/04_rules1.cf',
                        'laboris' => 't/04_rules1.cf',
                        'nisi' => 't/04_rules1.cf',
                        'ut' => 't/04_rules1.cf',
                        'aliquip' => 't/04_rules1.cf',
                        'ex' => 't/04_rules1.cf',
                        'ea' => 't/04_rules1.cf',
                        'commodo' => 't/04_rules1.cf',
                        'consequat' => 't/04_rules1.cf',
                        'duis' => 't/04_rules1.cf',
                        'dolore' => 't/04_rules1.cf',
                        'eu' => 't/04_rules1.cf',
                        'fugiat' => 't/04_rules1.cf',
                },
                't/04_rules0.cf' => {
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
                        'GROUP' => [
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
                't/04_rules1.cf' => {
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
                        'GROUP' => [
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
