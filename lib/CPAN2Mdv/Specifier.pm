#
#
#

package CPAN2Mdv::Specifier;

use strict;
use warnings;

use POE;



#--
# constructor

sub spawn {
    my ($type, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            '_start'  => \&_onpriv_start,
            'task'    => \&_onpub_task,
        },
    );
    return $session->ID;
}



#--
# private events

sub _onpriv_start {
    my ($k, $h, $args) = @_[KERNEL, HEAP, ARG0];
    my $alias = 'specifier';

    # store config.
    $h->{conf}  = $args;

    # set alias and finish startup.
    $k->alias_set( $alias );
    $k->post( 'journal', 'ident',      $alias );       # register to journal
    $k->post( 'main',    'rendezvous', $alias );       # signal main that we're started
    $k->post( 'journal', 'log', "start complete\n" );  # logging
}



1;
__END__
