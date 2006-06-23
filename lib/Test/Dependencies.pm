package Test::Dependencies;

use warnings;
use strict;

use Carp;
use File::Find;
use Module::CoreList;
use Pod::Strip;
use Test::More qw(no_plan);

use Exporter;
our @ISA = qw/Exporter/;

=head1 NAME

Test::Dependencies - Ensure that your Makefile.PL specifies all module dependencies

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

In your t/00-dependencies.t:

    use Test::Dependencies exclude =>
      [qw/ Your::Namespace Some::Other::Namespace /];

    ok_dependencies();

=head1 DESCRIPTION

Makes sure that all of the modules that are 'use'd are listed in the
Makefile.PL as dependencies.

=cut

our @EXPORT = qw/ok_dependencies/;

our $exclude_re;

sub import {
  if (scalar @_ == 3) {
    # package name, literal exclude, excluded namespaces
    my $exclude = $_[2];
    foreach my $namespace (@$exclude) {
      croak "$namespace is not a valid namespace"
        unless $namespace =~ m/^(?:(?:\w+::)|)+\w+$/;
    }
    $exclude_re = join '|', @$exclude;
  } elsif (scalar @_ != 1) {
    croak "wrong number of arguments while using Test::Dependencies";
  }
  Test::Dependencies->export_to_level(1, '', qw/ok_dependencies/);
}

sub ok_dependencies {
  my %used;

  my $wanted = sub {
    return unless -f $_;
    return if $File::Find::dir =~ m!/.svn($|/)!;
    return if $File::Find::name =~ /~$/;
    return if $File::Find::name =~ /\.pod$/;
    local $/;
    open(FILE, $_) or return;
    my $data = <FILE>;
    close(FILE);
    my $p = Pod::Strip->new;
    my $code;
    $p->output_string(\$code);
    $p->parse_string_document($data);
    $used{$1}++ while $code =~ /^\s*use\s+([\w:]+)/gm;
    while ($code =~ m|^\s*use base qw.([\w\s:]+)|gm) {
      $used{$_}++ for split ' ', $1;
    }
  };

  for my $dir (qw/ lib bin t /) {
    if ( -e $dir) {
      find( { wanted => $wanted,
              untaint => 1}, $dir);
    }
  }

  my %required;
  { 
    local $/;
    ok(open(MAKEFILE,"Makefile.PL"), "Opened Makefile");
    my $data = <MAKEFILE>;
    close(FILE);
    while ($data =~ /^\s*?requires\('([\w:]+)'(?:\s*=>\s*['"]?([\d\.]+)['"]?)?.*?(?:#(.*))?$/gm) {
      $required{$1} = $2;
      if (defined $3 and length $3) {
        $required{$_} = undef for split ' ', $3;
      }
    }
  }

  for (sort keys %used) {
    my $first_in = Module::CoreList->first_release($_);
    next if defined $first_in and $first_in <= 5.00803;
    next if /^($exclude_re)(::|$)/;
    ok(exists $required{$_}, "$_ in Makefile.PL");
    delete $used{$_};
    delete $required{$_};
  }

  for (sort keys %required) {
    my $first_in = Module::CoreList->first_release($_, $required{$_});
    fail("Required module $_ is already in core") if defined $first_in and $first_in <= 5.00803;
  }
}

=head1 AUTHORS

=over 4

=item * Jesse Vincent C<< <jesse at bestpractical.org> >>

=item * Alex Vandiver C<< <alexmv at bestpractical.org> >>

=item * Zev Benjamin, C<< <zev at cpan.org> >>

=back

=head1 BUGS

Please report any bugs or feature requests to
C<bug-test-dependencies at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Dependencies>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Dependencies

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-Dependencies>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-Dependencies>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-Dependencies>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-Dependencies>

=back

=head1 ACKNOWLEDGEMENTS

LICENCE AND COPYRIGHT
    Copyright (c) 2005, Best Practical Solutions, LLC. All rights reserved.

    This module is free software; you can redistribute it and/or modify it
    under the same terms as Perl itself. See perlartistic.

    DISCLAIMER OF WARRANTY

    BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
    FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
    OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
    PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
    EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
    ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
    YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
    NECESSARY SERVICING, REPAIR, OR CORRECTION.

    IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
    WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
    REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE
    TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR
    CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE
    SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
    RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
    FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
    SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH
    DAMAGES.

=cut

1;
