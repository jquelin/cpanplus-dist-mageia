#
# This file is part of CPAN2Mdv.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#

package CPAN2Mdv::Dist;

use strict;
use warnings;

use base qw[ Class::Accessor::Fast ];
__PACKAGE__->mk_accessors
    ( qw[ build_requires description extra_files is_prereq name module
        path pkgname requires rpm specfile srpm summary url version ] );

1;
__END__


=head1 NAME

CPAN2Mdv::Dist - a struct representing a distribution


=head1 DESCRIPTION

This module is an object acting as a bare struct with various fields
representing a distribution (using cpan's definition).

Apart the traditional constructor C<new>, the following accessors are
available:


=over 4

=item o $dist->build_requires()

A reference to an array, holding a list of requires (using rpm
definition). Note that since Mandriva provides some clever macros, it
usually boils down to a list of C<perl(Wanted::Package)>.

=back


=head1 COPYRIGHT & LICENSE

Copyright (c) 2007 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

