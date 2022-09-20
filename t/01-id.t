#!/usr/bin/perl

use Test::More;

use lib 'lib/';
use Mail::SpamAssassin::KeywordRuleGenerator;

my $id = '01';

my $kw = Mail::SpamAssassin::KeywordRuleGenerator->new('01');
ok ($kw->{'id'} == $id, "Get ID from attribute");
ok ($kw->id == $id, "Get ID from getter");
ok ($kw->id('Test') == 'Test', "Set ID with setter");
ok ($kw->id == 'Test', "Confirm set ID");

done_testing();
