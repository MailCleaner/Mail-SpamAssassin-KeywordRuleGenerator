#!/usr/bin/perl

# Basic smoke test for initializing module

use Test::More;

BEGIN {
        use lib 'lib/';
        use_ok( Mail::SpamAssassin::KeywordRuleGenerator );
};

ok (my $kw = Mail::SpamAssassin::KeywordRuleGenerator->new(), "Create default object");

my %args = (
        id => $id,
        debug => 1,
        single_outfile => 1
);

ok (my $kw = Mail::SpamAssassin::KeywordRuleGenerator->new( \%args ), "Create object with attributes");

done_testing();
