# Mail::SpamAssassin::KeywordRuleGenerator

Tool to make meta rules from much simpler config files

## Synopsis

This tool will take simple input like:

```
word
another 2
final group LOCAL
```

and generate complex meta rules to match the first keyword per line. The
optional number represents a standalone score for just that word while all
subsequent words represent a keyword group.

If no score is included, the word will only be used for a counter for all words
in the relevant groups. If no groups are listed, 'LOCAL' is implied. If one or
more groups is listed, LOCAL must be listed explicitly, otherwise that word
will not be used in the counter for the other words in that file.

The relatively simple output above will produce the following output:

```
body    __MC_TEST_ANOTHER_BODY /\banother\b/
header  __MC_TEST_ANOTHER_SUBJ Subject =~ /\banother\b/
meta    __MC_TEST_ANOTHER ( __MC_TEST_ANOTHER_BODY || __MC_TEST_ANOTHER_SUBJ )

body    __MC_TEST_WORD_BODY /\bword\b/
header  __MC_TEST_WORD_SUBJ Subject =~ /\bword\b/
meta    __MC_TEST_WORD ( __MC_TEST_WORD_BODY || __MC_TEST_WORD_SUBJ )

body    __MC_TEST_FINAL_BODY /\bfinal\b/
header  __MC_TEST_FINAL_SUBJ Subject =~ /\bfinal\b/
meta    __MC_TEST_FINAL ( __MC_TEST_FINAL_BODY || __MC_TEST_FINAL_SUBJ )

# LOCAL
meta    MC_TEST_1 ( __MC_TEST_WORD + __MC_TEST_ANOTHER + __MC_TEST_FINAL ) >= 1

meta    MC_TEST_2 ( __MC_TEST_WORD + __MC_TEST_ANOTHER + __MC_TEST_FINAL ) >= 2

meta    MC_TEST_3 ( __MC_TEST_WORD + __MC_TEST_ANOTHER + __MC_TEST_FINAL ) >= 3

# GROUP
meta    MC_TEST_GROUP_1 ( __MC_TEST_FINAL ) >= 1

meta    MC_TEST_ANOTHER ( __MC_TEST_ANOTHER )

# SCORES
describe    MC_TEST_1 Found 1 LOCAL word from MC_TEST
score       MC_TEST_1 0.01

describe    MC_TEST_2 Found 2 LOCAL words from MC_TEST
score       MC_TEST_2 0.01

describe    MC_TEST_3 Found 3 LOCAL words from MC_TEST
score       MC_TEST_3 0.01

describe    MC_TEST_GROUP_1 Found 1 GROUP word from MC_TEST
score       MC_TEST_GROUP_1 0.01

score       MC_TEST_ANOTHER 2
```

The initial 'body' and 'header' rules match the keyword in that respective
message component, and the first 'meta' rules simply indicate if one or then
other were hit. There are then a series of rules for each available hit count
for each group. Then there is a list of rules for the individual scoring rules.
Then, finally, there are all of the score definitions.

There are options to allow scores and rules to be combined in the same file
or split into separate files.

By default, a different (set of) file(s) will be generated for each input file,
but it is also possible to combine them into a single file. That same 'global'
file may already exist if any keywords are assigned to the special 'GLOBAL'
group.

For more detailed documentation, see inline POD or use perldoc after
installation:

```
perldoc Mail::SpamAssassin::KeywordRuleGenerator
```

## Dependencies

Mail::SpamAssassin - Required to test output and run build tests

This can be installed via CPAN, but it is also likely included in your
distribution's repositories:

```
# Debian/Ubuntu
apt install spamassassin
# RHEL/Fedora
dnf install spamassassin
```

## Installation

Clone the repository, change directory, generate makefile, then make:

```
git clone https://git.john.me.tz/jpm/Mail-SpamAssassin-KeywordRuleGenerator.git
cd KeywordRuleGenerator
./Makefile.PL
make install
```

## Disclaimer

This tool is not affiliated with SpamAssassin or Apache Software Foundation
