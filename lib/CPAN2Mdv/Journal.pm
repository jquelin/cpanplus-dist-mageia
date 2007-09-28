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
    my ($k, $h, $sender, @what) = @_[KERNEL, HEAP, SENDER, ARG0..$#_];

    # timestamp
    my $now  = DateTime->now( time_zone=>'local' );
    my $date = $now->month_abbr . '-' . $now->day;
    my $time = $now->hms;

    # from
    my $id   = $sender->ID;
    my $from = exists $h->{alias}{$id} ? $h->{alias}{$id} : $id;

    # log
    print "$date $time [$from] @what";
}


#--
# private events

sub _onpriv_start {
    my ($k, $h, $session, $args) = @_[KERNEL, HEAP, SESSION, ARG0];

    # store session names.
    $h->{alias} = {
        $args->{main} => 'main',
        $session->ID  => 'journal',
    };

    #my $h->{format} = DateTime::Format::Strptime->new( '%b-%d %T' );

    $k->yield('log', "start complete\n");
}

#--
# private subs


1;
__END__
