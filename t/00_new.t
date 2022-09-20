#!/usr/bin/perl

use Test::More;

BEGIN {
        use lib 'lib/';
        use_ok( Mail::SpamAssassin::KeywordRuleGenerator );
};

my $id = '00';

ok (my $kw = Mail::SpamAssassin::KeywordRuleGenerator->new($id), "Create object");

done_testing();
