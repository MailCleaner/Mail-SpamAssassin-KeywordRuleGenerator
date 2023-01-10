# <@LICENSE>
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to you under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# </@LICENSE>

=head1 NAME

Mail::SpamAssassin::KeywordRuleGenerator - Generate SA rules for keywords

=cut

package Mail::SpamAssassin::KeywordRuleGenerator;

=head1 SYNOPSIS

Generate SpamAssassin compatible configuration files given lists of keywords.
Implemented as a module largely for testing purposes.

    use Mail::SpamAssassin::KeywordRuleGenerator;
    my $kw = Mail::SpamAssassin::KeywordRuleGenerator->new($id);
    $kw->readFile('keywords.cf');
    $kw->writeAll();

=head1 DESCRIPTION

Mail::SpamAssassin::KeywordRuleGenerator does what it says on the tin; it
generates SpamAssassin compatible configuration files to catch keywords that you
specify. Most simply, it can take in one or more properly formatted input files
(see FILES), generate rules for individual files (optional), as well as meta
rules for the counts for each set of keywords (ie. 1 of N hit; 2 of N hit...).
See RULES for more on how the rules are generated.

The sets of keywords can be broken up into groups (see GROUPS).

=head1 PREREQUISITES

Requires C<spamassassin> executable and the following Perl modules

    Mail::SpamAssassin

=cut

use strict;
use warnings;

=head2 FILES

There are built-in functions to ingest formatted list files. See C<readFile>
method. By default, the output file name and the rules therein will use a
stripped and capitalized version of those filenames.

    $kw->readAll( 'example.cf', 'example.txt' );
    $kw->writeAll();

This will creates rules formatted like:

    ID_EXAMPLE_WORD

and will output to the file:

    70_ID_EXAMPLE.cf

Leading './' or $PWD will be stripped, but other paths will be included with '_'
substituted '/'. For example:

    $kw->readAll ( './example.cf', '/to/pwd/example2.cf', 'dir/example3.cf' );

will produce:

    70_KW_EXAMPLE.cf
    70_KW_EXAMPLE2.cf
    70_KW_DIR_EXAMPLE3.cf

If there are any rules in the 'GLOBAL' group, or if in C<singleOutfile> mode,
a file with just the priority and keyword will be produced with the select rules
or all rules, respectively. This will look like:

    70_KW.cf

See the C<generate*> methods for more information on this formatting. Also see
the C<new> method for discussion of the 'id'.

Finally, unless in C<joinScores> mode, each configuration will have a matching
scores file like:

    70_KW_EXAMPLE_SCORES.cf
    70_KW_SCORES.cf

In C<joinScores> mode, the scores will be directly appended in the same config
file with the rule definitions.

Note that the global files may have an incremented priority since it requires
all meta rules from the other files be defined first. For example, the above
would be left with 70 for the global priority, however if the C<id> were lower
in the alphabet, the global files would be incremented:

    70_AB_EXAMPLES.cf
    71_AB.cf

=head2 RULES

Two types of rules are created. One is a set of standalone keyword rules when a
score is provided for those words. This will create a meta rule for a simple
match in either the headers or body

header      __ID_FILE_WORD_H    /\bword\b/i
body        __ID_FILE_WORD_B    /\bword\b/i
meta        __ID_FILE_WORD      ( __ID_FILE_WORD_H || __ID_FILE_WORD_B )
meta        ID_FILE_WORD        __ID_FILE_WORD
describe    ID_FILE_WORD        Keyword 'word' found
score       ID_FILE_WORD        1

The other is a set of counters for each group. These will add the same first
three component rules (or co-opt the ones already created for the standalone
rules). It will then add a rule for each number of possible matches within that
group:

meta        ID_FILE_GROUP_1     ( __ID_FILE_WORD + __ID_FILE_OTHER ) > 0
describe    ID_FILE_GROUP_1     1 match in keyword group 'GROUP'
meta        ID_FILE_GROUP_2     ( __ID_FILE_WORD + __ID_FILE_OTHER ) > 1
describe    ID_FILE_GROUP_2     2 matches in keyword group 'GROUP'

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 EXPORT

=cut

use Exporter qw(import);
use base 'Exporter';

our @EXPORT = qw( new );

our %EXPORT_TAGS = (
    'all' => [
        'new',
        'getId',
        'setId',
        'getPriority',
        'setPriority',
        'getOutfile',
        'setOutfile',
        'getScoresOutfile',
        'setScoresOutfile',
        'getGlobalOutfile',
        'setGlobalOutfile',
        'getGlobalScoresOutfile',
        'setGlobalScoresOutfile',
        'getOutput',
        'getScoresOutput',
        'getGlobalOutput',
        'getGlobalScoresOutput',
        'clearFile',
        'nextFile',
        'readFile',
        'getFile',
        'setFile',
        'createDir',
        'cleanDir',
        'generateMetas',
        'generateScored',
        'generateGroups',
        'generateGlobals',
        'generateAll',
        'writeFile',
        'writeAll',
        'verifyOutput'
    ]
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{all} } );

=head1 METHODS

Except for getter methods, all methods make changes directly within the context
object and only return errors. Thus, each call can be verified by checking that
it returned undef:

    die "Failed to run 'method'\n" if($kw->method($arg));

or:

    my $err = $kw->method($arg);
    die "Received $err\n" if ($err);

Getter methods will return the attribute or undef if it does not exist.

=head2 C<$kw = new( %args )>

Creates a new C<Mail::SpamAssassin::KeywordRuleGenerator> object and returns it.

C<$args> is an optional hash to assign any preliminary attributes or flags to
the object. See various 'get' and 'set' functions.

=cut

sub new
{
    my ($class, $args) = @_;
    my $self = $args;

=head3 Initial attributes

While other attributes will exist within the object during processing, those
which make sense to define up-front and which will not be overwritten by any of
the built-in functions (other than their associated getters) are:

=head3 id

    id scalar
    A short identifier which will be appending to all output files to allow
    for easier recognition of the files' sources. Default: 'KW'

=cut

    $self->{'id'}           //= 'KW';

=head3 priority

    priority scalar
    Typically a number used to define the priority of the rules.
    SpamAssassin will read configuration files in alphabetical order and the
    last iteration of a configuration for the same rule will be used. This
    means that the files read last will overwrite those read earlier. By
    convention the number is used for easy sorting. Any leading aphabetical
    character will be ordered after all numbers, and so given high priority.
    Default: '50'

=cut

    $self->{'priority'}         //= 50;

=head3 debug

    debug boolean
    Enable (1) or disable (0) debugging output. Default: 0

=cut

    $self->{'debug'}        //= 0;

=head3 singleOutfile

    singleOutfile boolean
    Indicates whether output rules should all be added to a single file (1),
    or to one file per input file (0). Note that this still requires
    'joinScores' to have one file total. Default: 0

=cut

    $self->{'singleOutfile'}    //= 0;

=head3 joinScores

    joinScores bootlean
    Indicates whether to include the scores in the same file as their
    associated rule definitions (1) or in a second file on their own (0).
    The second file will simply append '_SCORES' to the file name (prior to
    the '.cf'), unless overridden by C<$kw->setScoreFile($path)> or a second
    path argument in C<$kw->setOutfile($rulePath, $scorePath)>. Default: 1

=cut

    $self->{'joinScores'}       //= 1;

    bless $self, $class;
    return $self;
}

=head2 C<$kw->getId()>

Getter for C<$kw->{'id'}>. 'id' is used for top-level rule names.

=cut

sub getId
{
    my $self = shift;

    if (defined($self->{'id'})) {
        return $self->{'id'};
    }
}

=head2 C<$kw->setId()>

Setter for C<$kw->{'id'}>

=cut

sub setId
{
    my $self = shift;
    my $id = shift;

    if (defined($id)) {
        $id = uc($id);
        return "Must start with a letter" unless ($id =~ m/^[A-Z]/);
        $self->{'id'} = $id || return "Failed to set $id";
    } else {
        return "No ID provided\n";
    }
}

=head2 C<$kw->getPriority()>.

Getter for C<$kw->{'priority'}>. 'priority' value used for the output filepath
to indicate the load order. SpamAssassin reads in ascending order with later
iterations overriding earlier. The 'score' file will increment so that it comes
at the end.

=cut

sub getPriority
{
    my $self = shift;

    if (defined($self->{'priority'})) {
        return $self->{'priority'};
    }
}

=head2 C<$kw->setPriority()>

Setter for C<$kw->{'priority'}>.

=cut

sub setPriority
{
    my $self = shift;
    my $priority = shift;

    if (defined($priority)) {
        $self->{'priority'} = $priority || return "Failed to set priority: $priority";
    } else {
        return "No 'priority' provided\n";
    }
}

=head2 C<$kw->getFile()>

Getter for C<$kw->{'file'}>. This is the name of the current output file being
processed. Not to be confused with C<readFile> or C<getOutfile>.

=cut

sub getFile
{
    my $self = shift;

    if (defined($self->{'file'})) {
        return $self->{'file'};
    }
    return undef;
}

=head2 C<$kw->setFile()>

Setter for C<$kw->{'file'}>.

=cut

sub setFile
{
    my $self = shift;
    my $file = shift;

    if (defined($file)) {
        $self->{'file'} = $file;
        $self->setOutfile();
        $self->setScoresOutfile();
    } else {
        delete($self->{'file'});
    }
}

=head2 C<$kw->getOutfile()>

Getter for C<$kw->{'file'}>. 'file' represents the real filepath of the
output file. With a single argument, the output file for that input file will be
returned. Without an argument, the current working output file will be returned,
if available).

=cut

sub getOutfile
{
    my $self = shift;
    my $file = shift || $self->{'file'};

    if (defined($self->{'filemap'}->{$file})) {
        return $self->{'outfile'};
    }
}

=head2 C<$kw->setOutfile()>

Setter for C<$kw->{'outfile'}>. Can be defined manually with a scalar argument,
otherwise the path is constructed from the existing attributes.

=cut

sub setOutfile
{
    my $self = shift;
    my $path = shift;

    if (defined($path)) {
        $self->{'filemap'}->{$self->{'file'}} = $path || return "Failed to set $path";
    } else {
        if ($self->{'singleOutfile'}) {
            $self->{'filemap'}->{$self->{'file'}} = $self->{'dir'}."/".$self->{'priority'} .
                '_' . uc($self->{'id'}) .
                '.cf';
        } else {
            my $file = $self->{'file'};
            $file =~ s/\//_/g; # Change dir slashes to _
            $file =~ s/(\.[^\.]*)$//g; # Remove extensions
            $file = uc($file); # Convert to uppercase for rule names

            $self->{'filemap'}->{$self->{'file'}} = $self->{'dir'}."/".$self->{'priority'} .
                '_' . uc($self->{'id'}) .
                '_' . $file .
                '.cf';
        }
    }
}

=head2 C<$kw->getScoresOutfile()>

Getter for the output path for scores for the current C<$kw->{'file'}>.

=cut

sub getScoresOutfile
{
    my $self = shift;
    my $file = shift || $self->{'file'};

    $self->setScoresOutfile() unless (defined($self->{'filemap'}->{$file."_SCORES"}));
    return $self->{'filemap'}->{$file."_SCORES"};
}

=head2 C<$kw->setScoresOutfile()>

Setter for the output path for scores for the current C<$kw->{'outfile'}>. Can
be defined manually with a scalar argument, otherwise the path is constructed
from the existing attributes.

=cut

sub setScoresOutfile
{
    my $self = shift;
    my $path = shift;

    if (defined($path)) {
        $self->{'filemap'}->{$self->{'file'}."_SCORES"} = $path || return "Failed to set $path";
        return undef;
    }
    if ($self->{'joinScores'}) {
        if ($self->{'singleOutfile'}) {
            $self->setGlobalOutfile() unless (defined($self->{'filemap'}->{'GLOBAL'}));
            $self->{'filemap'}->{$self->{'file'}."_SCORES"} = $self->{'filemap'}->{'GLOBAL'};
        } else {
            $self->setOutfile() unless (defined($self->{'filemap'}->{$self->{'file'}}));
            $self->{'filemap'}->{$self->{'file'}."_SCORES"} = $self->{'filemap'}->{$self->{'file'}};
        }
        return undef;
    } else {
        if ($self->{'singleOutfile'}) {
            $self->setGlobalScoresOutfile() unless (defined($self->{'filemap'}->{'GLOBAL_SCORES'}));
            $self->{'filemap'}->{$self->{'file'}."_SCORES"} = $self->{'filemap'}->{'GLOBAL_SCORES'};
            return undef;
        }
    }
    my $file = $self->{'file'};
    $file =~ s/\//_/g; # Change dir slashes to _
    $file =~ s/(\.[^\.]*)$//g; # Remove extensions
    $file = uc($file); # Convert to uppercase for rule names
    $self->{'filemap'}->{$self->{'file'}."_SCORES"} = $self->{'dir'}."/".$self->{'priority'} .
        '_' . uc($self->{'id'}) .
        '_' . $file .
        '_SCORES' .
        '.cf';
}

=head2 C<$kw->getGlobalOutfile();>

Return the full path of the output file used for GLOBAL rules. If it is not yet
defined, then C<setGlobalOutfile()> will be run first to try to set it. If this
fails, then nothing will be returned.

=cut

sub getGlobalOutfile
{
    my $self = shift;
    return $self->{'filemap'}->{'GLOBAL'} if (defined($self->{'filemap'}->{'GLOBAL'}));
    my $ret = $self->setGlobalOutfile();
    return $self->{'filemap'}->{'GLOBAL'} unless ($ret);
}

=head2 C<$kw->setGlobalOutfile($file);>

Set the output file for global rules. This file must be either the same or
alphabetically after the last file with 'meta' rules. C<$file> can be used to
bypass that check, but it might lead to rules that do not work.

Will try to select a filename as close to the existing output files as possible.
First it will simply duplicate a name if it is in C<singleOutfile> mode. Then,
it will try to use the base name without the C<$file> portion. This will
generally not work because the '_' before the file will come after the dot
without:

    99_KW.cf
    99_KW_FILE.cf
    99_KW_FILE_SCORES.cf

Next, if the priority is less than 99, it will simply increment that. Finally,
if will try to double the first '_':

    99__KW.cf

If none of these techniques work, it will return an error.

=cut

sub setGlobalOutfile
{
    my $self = shift;
    my $path = shift;

    if (defined($path)) {
        $self->{'filemap'}->{'GLOBAL'} = $self->{'filemap'}->{(keys(%{$self->{'filemap'}}))[0]};
        return undef;
    }
    if ($self->{'singleOutfile'}) {
        $self->{'filemap'}->{'GLOBAL'} = $self->{'filemap'}->{(keys(%{$self->{'filemap'}}))[0]};
        return undef;
    }
    my $last;
    foreach my $file (keys(%{$self->{'filemap'}})) {
        $last = $file if (!defined($last) || $file gt $last);
    }
    my $file = $self->getDir().'/'.$self->getPriority()."_".$self->getId().".cf";
    if (defined($last) && $file gt $last) {
        $self->{'filemap'}->{'GLOBAL'} = $file;
        return undef;
    }
    if ($self->getPriority < 99) {
        $self->{'filemap'}->{'GLOBAL'} = $self->getDir().'/'.($self->getPriority()+1)."_".$self->getId().".cf";
        return undef;
    }
    $file =~ s/_/__/ unless ($file gt $last);
    if ($file gt $last) {
        $self->{'filemap'}->{'GLOBAL'} = $file;
        return undef;
    }
    return ("Cannot determine a valid GLOBAL output file\n");
}

=head2 C<$kw->getGlobalScoresOutfile();>

Return the full path of the output file used for GLOBAL rules. If it is not yet
defined, then C<setGlobalOutfile()> will be run first to try to set it. If this
fails, then nothing will be returned.

=cut
sub getGlobalScoresOutfile
{
    my $self = shift;
    return $self->{'filemap'}->{'GLOBAL_SCORES'} if (defined($self->{'filemap'}->{'GLOBAL_SCORES'}));
    my $ret = $self->setGlobalScoresOutfile();
    return $self->{'filemap'}->{'GLOBAL_SCORES'} unless ($ret);
}

=head2 C<$kw->setGlobalScoresOutfile($file);>

Set the output file for the scores associated with global rules. This file must
be either the same or alphabetically after the global rules file. C<$file> can
be used to bypass that check, but it might lead to rules that do not work.

Will try to select a filename as close to the existing output files as possible.
First it will simply copy the global rules file name if it is in C<joinScores>
mode. Then, it will try to simply append '_SCORES' to the base file name prior
to the extension. Next, if the priority is less than 99, it will simply
increment that. Finally, if will try to double the first '_'. If none of these
techniques work, it will return an error.

=cut

sub setGlobalScoresOutfile
{
    my $self = shift;
    my $path = shift;

    if (defined($path)) {
        $self->{'filemap'}->{'GLOBAL_SCORES'} = $path;
        return undef;
    }
    $self->setGlobalOutfile() unless (defined($self->{'filemap'}->{'GLOBAL'}));
    if ($self->{'joinScores'}) {
        $self->{'filemap'}->{'GLOBAL_SCORES'} = $self->{'filemap'}->{'GLOBAL'};
        return undef;
    }
    if (defined($self->{'filemap'}->{'GLOBAL_SCORES'}) && $self->{'filemap'}->{'GLOBAL_SCORES'} gt $self->{'filemap'}->{'GLOBAL'}) {
        return undef;
    }
    my $file = $self->getGlobalOutfile() || die "HUH?";
    $file =~ s/\.cf$/_SCORES.cf/;
    if ($file gt $self->{'filemap'}->{'GLOBAL'}) {
        $self->{'filemap'}->{'GLOBAL_SCORES'} = $file;
        return undef;
    }
    $file = $self->getDir().'/'.$self->getPriority()."_".$self->getId()."_SCORES.cf";
    if ($file gt $self->{'filemap'}->{'GLOBAL'}) {
        $self->{'filemap'}->{'GLOBAL_SCORES'} = $file;
        return undef;
    }
    my $gpriority = $self->{'filemap'}->{'GLOBAL'};
    $gpriority =~ s/^(\d\d).*/$1/;
    $file = $self->getDir().'/'.($gpriority+1)."_".$self->getId()."_SCORES.cf" if ($gpriority < 99);
    if ($file gt $self->{'filemap'}->{'GLOBAL'}) {
        $self->{'filemap'}->{'GLOBAL_SCORES'} = $file;
        return undef;
    }
    $file = $self->{'filemap'}->{'GLOBAL'};
    $file =~ s/_/__/;
    if ($file gt $self->{'filemap'}->{'GLOBAL'}) {
        $self->{'filemap'}->{'GLOBAL_SCORES'} = $file;
        return undef;
    }
    return ("Cannot determine a valid GLOBAL output file\n");
}

=head2 C<$kw->getOutput()>

Returns a reference to the output array buffer for the current C<$file>.

=cut

sub getOutput
{
    my $self = shift;
    my $file = shift || $self->{'file'};

    if ($self->{'singleOutfile'}) {
        return \@{$self->{'output'}->{$self->{'filemap'}->{'GLOBAL'}}};
    } elsif (defined($self->{'filemap'}->{$file})) {
        return \@{$self->{'output'}->{$self->{'filemap'}->{$file}}};
    }
}

=head2 C<$kw->getScoresOutput()>

Returns a reference to the score output array buffer for the current C<$file>.

=cut

sub getScoresOutput
{
    my $self = shift;
    my $file = shift || $self->{'file'};

    $self->setScoreOutfile() unless (defined($self->{'filemap'}->{$file."_SCORES"}));
    if ($self->{'joinScores'}) {
        if ($self->{'singleOutfile'}) {
            return \@{$self->{'output'}->{$self->{'filemap'}->{'GLOBAL'}}};
        } elsif (defined($self->{'filemap'}->{$file})) {
            return \@{$self->{'output'}->{$self->{'filemap'}->{$file}}};
        }
    } else {
        if ($self->{'singleOutfile'}) {
            return \@{$self->{'output'}->{$self->{'filemap'}->{'GLOBAL_SCORES'}}};
        } elsif (defined($self->{'filemap'}->{$file})) {
            return \@{$self->{'output'}->{$self->{'filemap'}->{$file."_SCORES"}}};
        }
    }
}

=head2 C<$kw->getGlobalOutput()>

Returns a reference to the output array buffer for the GLOBAL file.

=cut

sub getGlobalOutput
{
    my $self = shift;

    $self->setGlobalOutfile() unless (defined($self->{'filemap'}->{'GLOBAL'}));
    return \@{$self->{'output'}->{$self->{'filemap'}->{'GLOBAL'}}};
}

=head2 C<$kw->getGlobalScoresOutput()>

Returns a reference to the output array buffer for the GLOBAL scores file.

=cut

sub getGlobalScoresOutput
{
    my $self = shift;

    $self->setGlobalScoresOutfile unless (defined($self->{'filemap'}->{'GLOBAL_SCORES'}));
    if ($self->{'joinScores'}) {
        return \@{$self->{'output'}->{$self->{'filemap'}->{'GLOBAL'}}};
    } else {
        return \@{$self->{'output'}->{$self->{'filemap'}->{'GLOBAL_SCORES'}}};
    }
}

=head2 C<$kw->clearFile();>

Clear the current file reference queue.

=cut

sub clearFile
{
    my $self = shift;
    my $file = shift || $self->{'file'};
    delete($self->{'rules'}->{$file}) || return "Failed to delete rules hash\n";
    return 0;
}

=head2 C<$kw->clearAll();>

Clear all file reference queues.

=cut

sub clearAll
{
    my $self = shift;
    foreach my $file (keys(%{$self->{'rules'}})) {
        %{$self->{'rules'}->{'DEFAULT'}} = () if ($file eq 'DEFAULT');
        $self->clearFile($file);
    }
    return 0;
}
=head2 C<$kw->readFile(%args);>

Read in properly formatted keyword list file. The basic format is one keyword
per line, an optional score, and an optional list of 'groups'.

So, the minimum is just one word per line:

    word

When the score is omitted, it will not have a standalone score. It will be used
solely as part of a keyword group.

When keyword groups are omitted, that keyword defaults to just the 'LOCAL' group
(see GROUPS).

Examples with other combinations are:

    word 0              # Same as previous
    word 2              # Used for LOCAL, not GLOBAL, scores 2
    word GROUP          # GROUP group, not LOCAL, not GLOBAL, no score
    word 0 GROUP        # Same as previous
    word 1 GROUP GLOBAL LOCAL   # GROUP group, in GLOBAL, in LOCAL, scores 1

C<%args> can be used to override the attributes used to index the rules,
including the id, file

This function intentionally does not iterate through the files queue so that you
can step through and make modifications as you go.

=cut

sub readFile
{
    my $self = shift;
    my $file = shift || return 'No file provided';
    my %args = @_;
    # Clean to relative path
    $file =~ s/^\.\///;
    $file =~ s/^$ENV{'PWD'}\///;

    $self->getDir();
    $self->{'file'} = $file;
    $self->setOutfile();

    my $n = 0;
    if (open(my $fh, '<', $file)) {
        my $rules = 0;
        while (<$fh>) {
            $n++;
            # Ignore blank lines and comments
            if ($_ =~ m/^\s*$/ || $_ =~ m/^#/) {
                next;
            # Verify formatting
            } elsif (my ($word, $score, $comment, @groups) = $self->readLine($_)) {
                if ($self->{'debug'}) {
                    print "FOUND: '$word' '$score' " . (join(',',@groups)) . "\n";
                }
                foreach my $group (@groups) {
                    # Global rules must references the file where the component rule is located
                    if ($group eq 'GLOBAL') {
                        $self->{'rules'}->{'GLOBAL'}->{$word} = $self->{'file'};
                    # Local rules have enough information from context to determine the component rule
                    } else {
                        push(@{$self->{'rules'}->{$self->{'file'}}->{$group}}, $word);
                    }
                }
                $self->{'rules'}->{$self->{'file'}}->{'SCORED'}->{$word} = $score if ($score);
                $self->{'rules'}->{$self->{'file'}}->{'COMMENTS'}->{$word} = $comment if ($comment);
            } elsif ($self->{debug}) {
                print STDERR "ERROR: Invalid input in $file, line $n: $_\n";
            }
        }
        print STDERR "No rules found in $file\n" unless ($self->{'rules'}->{$self->{'file'}} || !$self->{'debug'});
        return "No rules found in $file\n" unless ($self->{'rules'}->{$self->{'file'}});
    } else {
        delete($self->{'file'});
        return "Failed to read $file";
    }
    return undef;
}

=head2 C<$kw->readAll();>

Loops through C<readFile> for all files in the queue.

=cut

sub readAll
{
    my $self = shift;
    my @files = @_;

    my @failed;
    foreach my $file (@files) {
        if (!-e $file) {
            push(@failed, "$file does not exist\n");
            print STDERR "$file does not exist\n" if ($self->{'debug'});
        } elsif (-l $file) {
            # Accept only links within PWD
            my $dest = readlink($file);
            if ($dest =~ m/^\//) {
                $dest =~ s/$ENV{'PWD'}\/// ;
                if ($dest eq readlink($file)) {
                    push(@failed, "Symlink outside of PWD $file\n");
                    print STDERR "Symlink outside of PWD $file\n" if ($self->{'debug'});
                    next;
                }
            }
            $self->readAll($dest);
        } elsif (-f $file) {
            push(@failed, "Failed to read $file") if $self->readFile($file);
        } elsif (-d $file) {
            push(@failed, $self->readAll(glob($file.'/*')) );
        # Bash pattern?
        } else {
            if (my @glob = glob($file)) {
                push(@failed, ( @_ )) if $self->readAll(@glob);
            } else {
                print STDERR "Bad file $file\n" if ($self->{'debug'});
            }
        }
    }
    return @failed;
}

=head2 C<$kw->readLine($line)>

Reads a line from a configuration file and returns the relevant values or undef
if the line is not properly formatted.

=cut

sub readLine
{
    my $self = shift;
    my $line = shift;
    my @invalid;
    my ($word, $score, $comment, @groups);
    if (my @sections = $line =~ m/(?:^|\s+)(?:([^\d\s#]\S+)|(\d+(?:\.\d+)?\b)|([^\d\s#]+)|(#.*$))/g) {
        while (@sections) {
            next unless my $section = shift(@sections);
            if (defined($comment)) {
                $comment .= ' ' if ($comment ne '');
                $comment .= $section;
            } elsif (!defined($word) && $section =~ m/^([^\d\s#]\S+)$/) {
                $word = $section;
            } elsif (defined($word) && $section =~ m/^(\d+(?:\.\d+)?)$/ && !defined($score)) {
                $score = $section;
            } elsif (defined($word) && $section =~ m/^([^\d\s#]+)$/) {
                push(@groups, uc($section));
            } elsif (defined($word) && $section =~ m/^#.*$/ && !defined($comment)) {
                $comment = $section;
                $comment =~ s/^#\s*//;
            } else {
                push(@invalid, $section);
            }
        }
        if (scalar(@invalid)) {
            if ($self->{'debug'}) {
                print("Invalid clauses: '".join("', ", @invalid)."' in '$line'\n");
            }
            return undef;
        }
        return undef unless ($word);
        $word = lc($word);
        $score //= 0;
        $comment //= '';
        @groups = ( 'LOCAL' ) unless (scalar(@groups));
        return ( $word, $score, $comment, @groups );
    }
    return ();
}


=head2 C<$kw->getPrefix($file);>

Return a standardized rule prefix using C<id> and C<file>.

=cut

sub getPrefix
{
    my $self = shift;
    my $file = shift || $self->getFile();
    my $id = $self->getId();
    $file =~ s/(?:.*\/)*(.*)\.cf/$1/ if (defined($file));
    return uc($id.(defined($file) ? "_$file" : ''));
}

=head2 C<$kw->generateMetas($file);>

Write component rules for file in the current file, or one set by C<$file> to
make them available to all other rule types.

These are a match for each word across all groups and 'SCORED' in the body and
subject header, then a 'meta' rule to connect them.

    body    __KW_FILE_WORD_BODY /\bword\b/
    header  __KW_FILE_WORD_SUBJ Subject =~ /\bword\b/
    meta    __KW_FILE_WORD ( __KW_FILE_WORD_BODY || __KW_FILE_WORD_SUBJ )

=cut

sub generateMetas
{
    my $self = shift;
    my $words = shift;
    my $file = $self->getFile();
    my $prefix = $self->getPrefix();

    my $output = $self->getOutput();
    my $scoresoutput = $self->getScoresOutput();

    if ($self->{'debug'}) {
        print STDERR "Writing Metas for $file\n";
    }
    if ($self->{'singleOutfile'}) {
        push(@{$output},
            "############".('#'*length($prefix))."#\n".
            "# Metas for $prefix\n".
            "############".('#'*length($prefix))."#\n\n"
        );
    }
    foreach my $word (keys(%{$words})) {
        push(@{$output}, "# ".$words->{$word}."\n") if ($words->{$word});
        push(@{$output},
            "body    __${prefix}_".uc($word).
            "_BODY /\\b${word}\\b/\n",
            "header      __${prefix}_".uc($word).
            "_SUBJ Subject =~ /\\b${word}\\b/\n",
            "meta    __${prefix}_".uc($word).
            " ( __${prefix}_".uc($word)."_BODY || __${prefix}_".
            uc($word)."_SUBJ )\n\n"
        );
    }
}

=head2 C<$kw->generateScored($file);>

Write 'SCORED' word rules for file in the current file, or one set by C<$file>.

These are simply a 'meta' rule for only the existing component rule (the same
rule with a '__' prefix).

    meta    KW_FILE_WORD ( __KW_FILE_WORD )
    score       KW_FILE_WORD 1.0

=cut

sub generateScored
{
    my $self = shift;
    my $file = shift || $self->getFile();
    my $prefix = $self->getPrefix();

    my $output = $self->getOutput();
    my $scoreoutput = $self->getScoresOutput();
    if ($self->{'singleOutfile'}) {
        push(@{$output},
            "############".('#'*length($prefix))."#\n".
            "# Scored words for $prefix\n".
            "############".('#'*length($prefix))."#\n\n"
        );
    }
    foreach ( keys(%{$self->{'rules'}->{$file}->{'SCORED'}}) ) {
        push(@{$output}, "meta    ${prefix}_".uc($_).
            " ( __${prefix}_".uc($_)." )\n"
        );
        if (defined($self->{'rules'}->{$file}->{'COMMENTS'}->{$_})) {
            push(@{$scoreoutput}, "describe    ${prefix}_".uc($_)." ".
                $self->{'rules'}->{$file}->{'COMMENTS'}->{$_}.
                "\n"
            );
        }
        push(@{$scoreoutput},
            "score       ${prefix}_".uc($_)." ".
            $self->{'rules'}->{$file}->{'SCORED'}->{$_}."\n\n"
        );
    }
}

=head2 C<$kw->generateGroups($file);>

Write group rules for file in the current file, or one set by C<$file>. These
are a list of 'meta' rules where the component rules are all of the 'meta's in
the group for each of the available match counts.

    meta    KW_FILE_GROUP_1 ( __KW_WORD1 + __KW_WORD2 ) >= 1
    describe    KW_FILE_GROUP_1 Found 1 word(s) from GROUP
    score       KW_FILE_GROUP_1 0.01

    meta    KW_FILE_GROUP_2 ( __KW_WORD1 + __KW_WORD2 ) >= 2
    describe    KW_FILE_GROUP_2 Found 2 word(s) from GROUP
    score       KW_FILE_GROUP_2 0.01

=cut

sub generateGroups
{
    my $self = shift;
    my $file = shift || $self->getFile();
    my $prefix = $self->getPrefix();

    my $output = $self->getOutput();
    my $scoreoutput = $self->getScoresOutput();
    if ($self->{'singleOutfile'}) {
        push(@{$output},
            "#############".('#'*length($prefix))."#\n".
            "# Groups for $prefix\n".
            "#############".('#'*length($prefix))."#\n\n"
        );
    }
    foreach my $group ( keys(%{$self->{'rules'}->{$file}}) ) {
        next if ( $group eq 'COMMENTS' || $group eq 'SCORED' );
        push(@{$output}, "# $group\n");
        my $gprefix = $prefix;
        unless ($group eq 'LOCAL') {
            $gprefix .= '_'.$group;
        }
        my $start = "meta    ${gprefix}_";
        my $words = " ( ";
        foreach my $word ( @{$self->{'rules'}->{$file}->{$group}} ) {
            $words .= "__${prefix}_".uc($word)." + ";
        }
        $words =~ s/\+ $/\) >= /;
        for (my $i = 1; $i <= scalar(@{$self->{'rules'}->{$file}->{$group}}); $i++) {
            push(@{$output}, $start.$i.$words.$i."\n\n");
            push(@{$scoreoutput},
                "describe    ${gprefix}_$i Found $i $group word"
                . ($i>1 ? 's' : '')." from $prefix\n",
                "score       ${gprefix}_$i 0.01\n\n"
            );
        }
    }
}

=head2 C<$kw->generateGlobals();>

Write 'GLOBAL' group rules. Similar to C<generateGroups> except that component
rules must be included from external files.

    meta    KW_1 ( ( __KW_FILE1_WORD + __KW_FILE2_WORD ) >= 1 )
    describe    KW_1 Found 1 GLOBAL word(s) from KW
    score       KW_1 0.01

    meta    KW_2 ( ( __KW_FILE1_WORD + __KW_FILE2_WORD ) >= 2 )
    describe    KW_2 Found 2 GLOBAL word(s) from KW
    score       KW_2 0.01

=cut

sub generateGlobals
{
    my $self = shift;

    $self->setGlobalOutfile() unless (defined($self->{'filemap'}->{'GLOBAL'}));
    $self->setGlobalScoresOutfile() unless (defined($self->{'filemap'}->{'GLOBAL_SCORES'}));
    my $output = $self->getGlobalOutput();
    my $scoreoutput = $self->getGlobalScoresOutput();
    if ($self->{'singleOutfile'}) {
        push(@{$output},
            "##########\n".
            "# Globals\n".
            "##########\n\n"
        );
    }
    $self->setFile(undef);
    my $gprefix = $self->getPrefix();
    my $start = "meta    ${gprefix}_";
    my $words = " ( ";
    my $prefix;
    foreach my $word ( keys(%{$self->{'rules'}->{'GLOBAL'}}) ) {
        $prefix = $self->getPrefix($self->{'rules'}->{'GLOBAL'}->{$word});
        $words .= "__${prefix}_" . uc($word) . " + ";
    }
    $words =~ s/\+ $/\) >= /;
    for (my $i = 1; $i <= scalar(keys(%{$self->{'rules'}->{'GLOBAL'}})); $i++) {
        my $line = $start.$i.$words.$i."\n";
        push(@{$output}, $line.($self->{'joinScores'} ? '' : "\n"));
        push(@{$scoreoutput}, "describe    ${gprefix}_${i} Found $i ".
            "GLOBAL word(s) from ${gprefix}\n",
            "score       ${gprefix}_${i} 0.01\n\n"
        );
    }
}

sub getDir
{
    my $self = shift;
    my $dir = $self->{'dir'} || $self->setDir();
    return $dir;
}

sub setDir
{
    my $self = shift;
    my $dir = shift || ("$ENV{'PWD'}/$self->{'id'}");
    $dir =~ m/([^\0]+)/;
    $self->{'dir'} = $1;
    return undef;
}

sub createDir
{
    my $self = shift;
    my $dir = shift || $self->getDir();
    unless (-d $dir) {
        mkdir($dir) || return "Failed to mkdir '$dir'";
    }
    return undef;
}

sub cleanDir
{
    my $self = shift;
    my @files = @_;
    unless (scalar(@files)) {
        my %uniq;
        foreach (keys(%{$self->{'filemap'}})) {
            $uniq{$_} = 1;
        }
        @files = keys(%uniq);
    }
    foreach my $file (@files) {
        if (-e $self->{'filemap'}->{$file}) {
            if ($self->{'debug'}) {
                print STDERR "Removing old file ".$self->{'filemap'}->{$file}."\n";
            }
            unlink($self->{'filemap'}->{$file}) || die "Output file '".$self->{'filemap'}->{$file}."' exists and could not be deleted\n";
        }
    }
}

=head2 C<$kw->generateAll($dir)>

Output files will use the name of each input file, stripping any extension, and
forcing the name to uppercase. Rules in each file will be called:

      ID_FILENAME_WORD
      ID_FILENAME_GROUP_1

where

ID      - Meaningful identifier. From C<$kw->new($id)>, or with C<$kw->id($id)>.
FILENAME- Trimmed input file name. Override with C<$kw->file($file)>. Absent
      for GLOBAL.
WORD    - The individual keyword. Used only if it has a independent score.
GROUP   - The group name. Absent for 'LOCAL'.
1       - The count for hits in that group.

For each scoring rule above, there will be constituent meta rules for each
keyword, as well as further consituent rules to match both the subject and the
body for that word.

=cut

sub generateAll
{
    my $self = shift;
    my @written;

    $self->cleanDir() if (-d $self->getDir());
    $self->createDir() unless (-d $self->getDir());

    foreach my $file (keys(%{$self->{'rules'}})) {
        # Reserve GLOBAL for last
        next if ($file eq 'GLOBAL');
        $self->setFile($file);
        my %all;
        foreach my $group (keys(%{$self->{'rules'}->{$file}})) {
            if ($group eq 'SCORED' || $group eq 'COMMENTS') {
                next;
            } else {
                foreach my $word (@{$self->{'rules'}->{$file}->{$group}}) {
                    $all{$word} = $self->{'rules'}->{$file}->{'COMMENTS'}->{$word} || '';
                }
            }
        }
        $self->generateMetas(\%all);
        $self->generateGroups();
        $self->generateScored() unless ($self->{joinScores});
    }
    $self->generateGlobals();
    return 0;
}

=head2 C<$kw->writeFile($file)>

=cut

sub writeFile
{
    my $self = shift;
    my $file = shift || return "Requires filename";
    return "Nothing generated for $file" unless (defined($self->{'output'}->{$file}));

    return unless (scalar(@{$self->{'output'}->{$file}}));
    if (open(my $fh, ">", $file)) {
        foreach my $line (@{$self->{'output'}->{$file}}) {
            print $fh $line;
        }
        close($fh);
    } else {
        return "Could not open $file for writing";
    }
}

=head2 C<$kw->writeAll()>

=cut

sub writeAll
{
    my $self = shift;
    $self->generateAll() unless (defined($self->{'output'}));
    my @errors;
    foreach my $file (keys(%{$self->{'output'}})) {
        my $ret = $self->writeFile($file);
        push(@errors, $ret) if (defined($ret));
    }
    return ("Errors:\n ".join("\n ", @errors)) if (scalar(@errors));
}

=head2 C<$kw->verifyOutput()>

Process output directory with SpamAssassin linter. Return errors or
undef if successful. An optional C<$path> can be provided to test a
different file or directory.

=cut

sub verifyOutput
{
    my $self = shift;
    my $path = shift || $self->{'dir'};

    use Mail::SpamAssassin;
    my $sa = Mail::SpamAssassin->new( { 'site_rules_filename' => $path } );

    return $sa->lint_rules();
}

=head1 MORE

For discussion of the module and examples, see:

E<lt>https://john.me.tz/projects/article.php?topic=Mail-SpamAssassin-KeywordRuleGenerator<gt>

=head1 SEE ALSO

Mail::SpamAssassin
spamassassin

=head1 BUGS

Report issues to:

E<lt>https://git.john.me.tz/jpm/Mail-SpamAssassin-KeywordRuleGenerator/issuesE<gt>

=head1 AUTHOR

John Mertz <git@john.me.tz>

=head1 COPYRIGHT

Mail::SpamAssassin::KeywordRuleGenerator is distributed under the Apache License
Version 2.0, as described in this file and the file C<LICENSE> included with the
distribution.

=head1 AVAILABILITY

If possible, the latest version of this library will be made available from CPAN
as well as:

E<lt>https://git.john.me.tz/jpm/Mail-SpamAssassin-KeywordRuleGeneratorE<gt>

=cut

1;
