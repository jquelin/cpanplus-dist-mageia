#
#

package CPAN2Mdv::Journal;

use DateTime;
use POE;


#--
# constructor

sub spawn {
    my ($type, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            # private events
            '_start'    => \&_onpriv_start,
            # public events
            'log'       => \&_onpub_log,
        },
    );
    return $session->ID;
}


#--
# public events

sub _onpub_log {
    my ($k, $h, @what) = @_[KERNEL, HEAP, ARG0..$#_];

    my $now  = DateTime->now( time_zone=>'local' );
    my $date = $now->month_abbr . '-' . $now->day;
    my $time = $now->hms;

    print "$date $time @what";
}


#--
# private events

sub _onpriv_start {
    my ($k, $h, $args) = @_[KERNEL, HEAP, ARG0];
    #my $h->{format} = DateTime::Format::Strptime->new( '%b-%d %T' );

    $k->yield('log', "journal has started\n");
}

#--
# private subs


1;
__END__
