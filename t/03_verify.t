#!/usr/bin/perl

# Verify file input line formatting

use Test::More;

use lib 'lib/';
use Mail::SpamAssassin::KeywordRuleGenerator;

my $id = '03';

my $kw = Mail::SpamAssassin::KeywordRuleGenerator->new( { 'id' => $id, 'debug' => 0 } );

my @good = (
        'Lorem 1 GLOBAL # comment',
        'ipsum 0 GLOBAL # comment',
        'dolor GLOBAL # comment',
        'sit 1 # comment',
        'amet 0 # comment',
        'consectetur # comment',
        'adipiscing 1 GLOBAL',
        'elit 0 GLOBAL',
        'sed GLOBAL',
        'do 1',
        'eiusmod 0',
        'tempor',
);
foreach my $score ( '', 0, 1 ) {
        foreach my $group ( '', 'GLOBAL', 'GLOBAL LOCAL' ) {
                foreach my $comment ( '', 'TESTING', 'LONGER COMMENT' ) {
                        my $word = "word";
                        my $rule = $word;
                        if ($score ne '') {
                                $rule .= ' '.$score;
                        }
                        if ($group ne '') {
                                $rule .= ' '.$group;
                        }
                        if ($comment ne '') {
                                $rule .= ' # '.$comment;
                        }
                        my ($rword, $rscore, $rcomment, @rgroups) = $kw->readLine($rule);
                        ok($rword eq $word, "Word '$word' found for '$rule'");
                        ok($rscore eq $score, "Score '$score' found for '$rule'") if ($score ne '');
                        ok(join(' ',@rgroups) eq $group, "Groups '$group' found for '$rule'") if ($group ne '');
                        ok(join(' ',@rgroups) eq 'LOCAL GLOBAL', "Inferred groups 'LOCAL GLOBAL' found for '$rule'") if ($group eq '');
                        ok($rcomment eq $comment, "Comment '$comment' found for '$rule'") if ($comment ne '');
                }
        }
}

# Check for bad formatting

my %bad = (
        '' => 'Ignore empty line',
        '# comment' => "Ignore line starting with comment",
        'word 1 2' => "Ignore line with multiple scores",
        '2 bad' => "Ignore line with score first",
);
foreach my $input (keys(%bad)) {
        ok(!$kw->readLine($input), "$bad{$input} ($input)");
}

done_testing();
