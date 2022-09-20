#!/usr/bin/perl

package Mail::SpamAssassin::KeywordRuleGenerator;

use strict;
use warnings;

=head1 NAME

Mail::SpamAssassin::KeywordRuleGenerator - Generate SA rules for keywords

=cut

our $VERSION = '0.01';

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

Generate SpamAssassin compatible configuration files given lists of keywords.
Implemented as a module largely for testing purposes.

    use Mail::SpamAssassin::KeywordRuleGenerator;

=head2 FILES

There are built-in functions to ingest formatted list files. See C<readFiles>
method. By default, the output file name and the rules therein will use a
stripped and capitalized version of those filenames.

    $kw->readFiles( 'example.txt' );
    $kw->writeFiles();

This will creates rules formatted like:

    ID_EXAMPLE_WORD

and will output to the file:

    70_id_example.cf

See the C<writeFile> method for more information on this formatting. Also see
the C<new> method for discussion of the 'id'.

Finally, a like file:

    71_id_scores.cf

Will be created with the scores for all of the rules in the prior file(s). The
C<join_scores> variable is true by default, creating the above file. If made
false, then will determine a unique score file will be created for each file.
Alternatively, C<append_scores> can be set to include the scores directly in the
config file with the rule definitions.

=head2 RULES

Two types of rules are created. One is a set of standalone keyword rules when a
score is provided for those words. This will create a meta rule for a simple
match in either the headers or body

header          __ID_FILE_WORD_H        /\bword\b/i
body            __ID_FILE_WORD_B        /\bword\b/i
meta            __ID_FILE_WORD          ( __ID_FILE_WORD_H || __ID_FILE_WORD_B )
meta            ID_FILE_WORD            __ID_FILE_WORD
describe        ID_FILE_WORD            Keyword 'word' found
score           ID_FILE_WORD            1

The other is a set of counters for each group. These will add the same first
three component rules (or co-opt the ones already created for the standalone
rules). It will then add a rule for each number of possible matches within that
group:

meta            ID_FILE_GROUP_1         ( __ID_FILE_WORD + __ID_FILE_OTHER ) > 0
describe        ID_FILE_GROUP_1         1 match in keyword group 'GROUP'
meta            ID_FILE_GROUP_2         ( __ID_FILE_WORD + __ID_FILE_OTHER ) > 1
describe        ID_FILE_GROUP_2         2 matches in keyword group 'GROUP'

=head1 EXPORT

=cut

use Exporter qw(import);
use base 'Exporter';

our @EXPORT = qw( new );

our %EXPORT_TAGS = (
        'all' => [
                'new',
                ''
        ]
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{all} } );

=head1 SUBROUTINES/METHODS

=head2 C<$kw = new($id)>

Creates a new C<Mail::SpamAssassin::KeywordRuleGenerator> object and returns it.

C<$id> is an optional identifier which will be used to prefix any rule output.
It can be updated at any time via the C<$kw->{id}> value or with the
C<$kw->id($id)> setter;

=cut

sub new
{
        my ($class, $id) = @_;

        $id = uc($id) || 'KW';
        bless {
                id => $id || '',
                keywords => {}
        } => $class;
}

=head2 C<$kw->id()>

Get/Setter for C<$kw->{'id'}>

=cut

sub id
{
        my $self = shift;
        my $id = shift;

        if (defined($id)) {
                $id = uc($id);
                $self->{'id'} = $id;
        } else {
                if (defined($self->{'id'})) {
                        return $self->{'id'};
                } else {
                        return undef;
                }
        }
}

=head2 C<$kw->file()>

Get/Setter for C<$kw->{'file'}>

=cut

sub file
{
        my $self = shift;
        my $file = shift;

        if (defined($file)) {
                my $name = $file;
                $name =~ s/^([a-zA-Z0-9\-_]*)(\..*)?$/$1/;
                $name =~ s/-/_/;
                $name = uc($name);
                die("invalid filename\n") unless ($name =~ m/^[A-Z_]+$/);
                $self->{'file'} = $name;
        } else {
                if (defined($self->{'file'})) {
                        return $self->{'file'};
                } else {
                        return undef;
                }
        }
}

=head2 C<$kw->getFile();>

Simple recursive search for files within a directory. Will validate that each
file is readable and return an array of file names.

Expects a single file or directory path scalar as first argument and an optional
regex as the secord. If you have multiple entries to fetch, run separately and
append to your array.

The regex will be used as a file filter and will only return files that match.

=cut

sub getFiles
{
        my $self = shift;
        my @args = @_;

        foreach (@args) {
                die "$_ does not exist\n" unless (-e "$_" || -l "$_");
                if (-l $_) {
                        getFiles(readlink($_));
                } elsif (-d $_) {
                        my @recursive = glob($_."/*");
                        getFiles(@recursive);
                } else {
                        die "$_ is not readable\n" unless (-r "$_");
                        push(@{$self->{files_ref}}, $_);
                }
        }
        return @$self->{files_ref};
}

=head2 C<$kw->readFile();>

Read in properly formatted keyword list file. The basic format is one keyword
per line, an optional score, and an optional list of 'groups'.

So, the minimum is just one word per line:

    word

When the score is omitted, it will not have a standalone score. It will be used
solely as part of a keyword group.

When keyword groups are omitted, that keyword defaults to just the 'LOCAL' group
(see GROUPS).

Examples with other combinations are:

# word 0                        Same as previous
# word 2                        Used for LOCAL, not GLOBAL, scores 2 on it's own
# word GROUP                    GROUP group, not LOCAL, not GLOBAL, no score
# word 0 GROUP                  Same as previous
# word 1 GROUP GLOBAL LOCAL     GROUP group, in GLOBAL, in LOCAL, scores 1

=cut

sub readFiles
{
        my $key_ref = shift;
        my @files = @_;

        foreach my $file (@files) {
                my $n = 0; # Track line number for errors
                my $name = $file;
                $name =~ s/\//_/g; # Change dir slashes to _
                $name =~ s/(\.[^\.]*)*$//g; # Remove extensions
                $name = uc($name); # Convert to uppercase for rule names
                if (open(my $fh, '<', $file)) {
                        while (<$fh>) {
                                $n++;
                                # Ignore blank lines and comments
                                if ($_ =~ m/^\s*$/ || $_ =~ m/^#/) {
                                        next;
                                # Verify formatting
                                } elsif ($_ =~ m/^([^\s]+)\s+([0-9]+)(?:\s+(.*))?/) {
                                        my ($word, $score, $groups) = ($1, $2, $3);
                                        print "'$word' '$score' " . (join(',',$groups)) . "\n";
                                } else {
                                        die "Invalid input in $file, line $n: $_\n";
                                }
                        }
                }
        }
        #print "$_\n" foreach(@$files_ref);
}

=head 2 C<$kw->writeFiles($out_dir)>

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

sub writeFiles
{
        my $self = shift;
        my $dir = shift;

        use Data::Dump;
        print Data::Dump::dump($self->{keywords});
        return 0;
}

=pod
die "Please provide rules file(s) as an argument\n" unless (defined($ARGV[0]));

my @files;
my $files_ref = \@files;
getFiles($files_ref, @ARGV);

my %keywords;
my $key_ref = \%keywords;
readFiles($key_ref, @files);
=cut
