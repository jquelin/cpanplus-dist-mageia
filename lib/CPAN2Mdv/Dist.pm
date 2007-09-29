#
#
#

package CPAN2Mdv::Dist;

use strict;
use warnings;

use base qw[ Class::Accessor::Fast ];
__PACKAGE__->mk_accessors
    ( qw[ name module version ] );

1;
__END__
