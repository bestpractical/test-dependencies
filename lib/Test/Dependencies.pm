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

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

In your t/00-dependencies.t:

    use Test::Dependencies exclude =>
      [qw/ Your::Namespace Some::Other::Namespace /];

    ok_dependencies();

=head1 DESCRIPTION

Makes sure that all of the modules that are 'use'd are listed in the
Makefile.PL as dependencies.

=cut

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
  Test::Dependencies->export_to_level(1, qw/ok_dependencies/);
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
  
  find( $wanted, qw/ lib bin t /);

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

=item * Jesse Vincent C<< jesse at bestpractical.org >>

=item * Alex Vandiver C<< alexmv at bestpractical.org >>

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

=head1 COPYRIGHT & LICENSE

Copyright 2006 Zev Benjamin, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
