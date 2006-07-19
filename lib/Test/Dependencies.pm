package Test::Dependencies;

use warnings;
use strict;

use B::PerlReq;
use Carp;
use File::Find::Rule;
use Module::CoreList;
use PerlReq::Utils qw(path2mod);
use YAML qw(LoadFile);

use base 'Test::Builder::Module';

=head1 NAME

Test::Dependencies - Ensure that your Makefile.PL specifies all module dependencies

=head1 VERSION

Version 0.04

=cut

our $VERSION = '0.05';

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
  my $package = $_[0];
  my $callerpack = caller;
  my $tb = __PACKAGE__->builder;
  $tb->exported_to($callerpack);
  $tb->no_plan;

  if (scalar @_ == 3) {
    # package name, literal exclude, excluded namespaces
    my $exclude = $_[2];
    foreach my $namespace (@$exclude) {
      croak "$namespace is not a valid namespace"
        unless $namespace =~ m/^(?:(?:\w+::)|)+\w+$/;
    }
    $exclude_re = join '|', @$exclude;
  } elsif (scalar @_ != 1) {
    croak "wrong number of arguments while using Test::Dependencies: " . join ' ', @_;
  }
  $package->export_to_level(1, '', qw/ok_dependencies/);
}

sub _get_files_in {
  my @dirs = @_;
  my $rule = File::Find::Rule->new;
  $rule->or($rule->new
                 ->directory
                 ->name('.svn')
                 ->prune
                 ->discard,
            $rule->new
                 ->directory
                 ->name('CVS')
                 ->prune
                 ->discard,
            $rule->new
                 ->name(qr/~$/)
                 ->discard,
            $rule->new
                 ->name(qr/\.pod$/)
                 ->discard,
            $rule->new
                 ->not($rule->new->file)
                 ->discard,
            $rule->new);
  return $rule->in(grep {-e $_} @dirs);
}

sub _taint_flag {
  my $filename = shift;
  open FILE, $filename
    or warn "Could not open '$filename': $!";
  my $shebang = <FILE>;
  close FILE;
  if (defined $shebang) {
    chomp $shebang;
    if ($shebang =~ m/^#!.*perl.*-T/) {
      return '-T';
    }
  }
  return '';
}

sub _get_modules_used_in {
  my @dirs = @_;
  my @sourcefiles = _get_files_in(@dirs);
  my $perl = $^X;
  my %deps;
  foreach my $file (@sourcefiles) {
    my $taint = _taint_flag($file);
    my $output = `$perl $taint -MO=PerlReq '$file' 2> /dev/null`;
    # path2mod sucks, but the mod2path that B::PerlReq uses sucks, too
    my @filedeps = map { s/^perl\((.+)\)$/$1/; path2mod($_) }
               split /\n/, $output;
    $deps{$_}++ foreach @filedeps;
  }
  return keys %deps;
}

sub _get_used {
  return _get_modules_used_in(qw/bin lib/);
}

sub _get_build_used {
  return _get_modules_used_in(qw/t/);
}

=head1 EXPORTED FUNCTIONS

=head2 ok_dependencies

This should be the only test called in the test file.  It scans
bin/ and lib/ for module usage and t/ for build usage.  It will
then test that all modules used are listed as required in
Makefile.PL, all modules used in t/ are listed as build required,
that all modules listed are actually used, and that modules that
are listed are not in the core list.

=cut

sub ok_dependencies {
  my $tb = __PACKAGE__->builder;
  my %used = map { $_ => 1 } _get_used;
  my %build_used = map { $_ => 1 } _get_build_used;

  # remove modules from build deps if they are hard deps
  foreach my $mod (keys %used) {
    delete $build_used{$mod} if exists $build_used{$mod};
  }

  if (-r 'META.yml') {
    $tb->ok(1, 'META.yml is present and readable');
  } else {
    $tb->ok(0, 'META.yml is present and readable');
    $tb->diag("You seem to be missing a META.yml.  I can't check which dependencies you've declared without it\n");
    return;
  }
  my $meta = LoadFile('META.yml') or die 'Could not load META.YML';
  my %required = exists $meta->{requires} && defined $meta->{requires} ? %{$meta->{requires}} : ();
  my %build_required = exists $meta->{build_requires} ? %{$meta->{build_requires}} : ();

  my @in_core;
  
  foreach my $mod (sort keys %used) {
    my $first_in = Module::CoreList->first_release($mod);
    if (defined $first_in and $first_in <= 5.00803) {
      delete $used{$mod};
      push @in_core, $mod if exists $required{$mod};
      next;
    }
    if (defined $exclude_re && $mod =~ m/^($exclude_re)(::|$)/) {
      delete $used{$mod};
      next;
    }
    $tb->ok(exists $required{$mod}, "requires('$mod') in Makefile.PL");
    delete $used{$mod};
    delete $required{$mod};
  }

  foreach my $mod (sort keys %build_used) {
    my $first_in = Module::CoreList->first_release($mod);
    if (defined $first_in and $first_in <= 5.00803) {
      delete $build_used{$mod};
      push @in_core, $mod if exists $build_required{$mod};
      next;
    }
    if (defined $exclude_re && $mod =~ m/^($exclude_re)(::|$)/) {
      delete $build_used{$mod};
      next;
    }
    $tb->ok(exists $build_required{$mod}, "build_requires('$mod') in Makefile.PL");
    delete $build_used{$mod};
    delete $build_required{$mod};
  }  

  foreach my $mod (sort @in_core) {
    $tb->ok(0, "Required module $mod is already in core");
  }
  
  foreach my $mod (sort keys %required) {
    $tb->ok(0, "$mod is not a dependency");
  }

  foreach my $mod (sort keys %build_required) {
    $tb->ok(0, "$mod is not a build dependency");
  }

}

=head1 AUTHORS

=over 4

=item * Jesse Vincent C<< <jesse at bestpractical.com> >>

=item * Alex Vandiver C<< <alexmv at bestpractical.com> >>

=item * Zev Benjamin C<< <zev at cpan.org> >>

=back

=head1 BUGS

=over 4

=item * Test::Dependencies does not track module version requirements.

=item * Perl version for "already in core" test failures is hardcoded.

=back

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

=head1 LICENCE AND COPYRIGHT

    Copyright (c) 2006, Best Practical Solutions, LLC. All rights reserved.

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
