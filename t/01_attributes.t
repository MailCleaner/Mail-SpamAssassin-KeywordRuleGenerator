#!/usr/bin/perl

# Test that object attributes can be set and get

use Test::More;

use lib 'lib/';
use Mail::SpamAssassin::KeywordRuleGenerator;

my $defaults = {
        'id'            => 'KW',
        'priority'      => 50,
        'debug'         => 0,
        'singleOutfile' => 0,
        'joinScores'    => 1
};

my $args = {
        'id'            => 'TEST',
        'priority'      => 10,
        'debug'         => 1,
        'singleOutfile' => 1,
        'joinScores'    => 0
};

# Default object
my $kwd = Mail::SpamAssassin::KeywordRuleGenerator->new();
# Object with initialization arguments
my $kwi = Mail::SpamAssassin::KeywordRuleGenerator->new( $args );

# id
ok ($kwd->{'id'} == $defaults->{'id'}, "Get default 'id' from object hash");
ok ($kwd->getId() == $defaults->{'id'}, "Get default 'id' from getter");
ok ($kwi->{'id'} == $args->{'id'}, "Get 'id' from initialized object hash");
ok ($kwi->getId() == $args->{'id'}, "Get non-default 'id' from initialized getter");
ok ($kwd->setId($args->{'id'}), "Set 'id' with setter");
ok ($kwd->{'id'} == $args->{'id'}, "Get non-default 'id' from object hash");
ok ($kwd->getId() == $args->{'id'}, "Get non-default 'id' from getter");
$kwd->{'id'} = 'XYZ';
ok ($kwd->{'id'} == 'XYZ', "Manual set of 'id' attribute");
# priority
ok ($kwd->{'priority'} == $defaults->{'priority'}, "Get default 'priority' from object hash");
ok ($kwd->getPriority() == $defaults->{'priority'}, "Get default 'priority' from getter");
ok ($kwi->{'priority'} == $args->{'priority'}, "Get non-default 'priority' from object hash");
ok ($kwi->getPriority() == $args->{'priority'}, "Get non-default 'priority' from initialized getter");
ok ($kwd->setPriority($args->{'priority'}), "Set 'priority' with setter");
ok ($kwd->{'priority'} == $args->{'priority'}, "Get non-default 'priority' from object hash");
ok ($kwd->getPriority() == $args->{'priority'}, "Get non-default 'priority' from getter");
$kwd->{'priority'} = 0;
ok ($kwd->{'priority'} == 0, "Manual set of 'priority' attribute");
# debug - No getter or setter. This should be defined during 'new', but can be overwritten manually.
ok ($kwd->{'debug'} == $defaults->{'debug'}, "Get default 'debug' from object hash");
ok ($kwi->{'debug'} == $args->{'debug'}, "Get non-default 'debug' from object hash");
$kwd->{'debug'} = 1;
ok ($kwd->{'debug'} == 1, "Manual set of 'debug' attribute");
# singleOutfile - No getter or setter. This should be defined during 'new', but can be overwritten manually.
ok ($kwd->{'singleOutfile'} == $defaults->{'singleOutfile'}, "Get default 'singleOutfile' from object hash");
ok ($kwi->{'singleOutfile'} == $args->{'singleOutfile'}, "Get non-default 'singleOutfile' from object hash");
$kwd->{'singleOutfile'} = $args->{'singleOutfile'};
ok ($kwd->{'singleOutfile'} == $args->{'singleOutfile'}, "Manual set of 'singleOutfile' attribute");
# joinScores - No getter or setter. This should be defined during 'new', but can be overwritten manually.
ok ($kwd->{'joinScores'} == $defaults->{'joinScores'}, "Get default 'joinScores' from object hash");
ok ($kwi->{'joinScores'} == $args->{'joinScores'}, "Get non-default 'joinScores' from object hash");
$kwd->{'joinScores'} = $args->{'joinScores'};
ok ($kwd->{'joinScores'} == $args->{'joinScores'}, "Manual set of 'joinScores' attribute");

done_testing();
