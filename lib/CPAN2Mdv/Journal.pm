#
# This file is part of CPAN2Mdv.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#

package CPAN2Mdv::Journal;

use strict;
use warnings;

use DateTime;
use POE;


#--
# constructor

sub spawn {
    my ($type, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            '_start'    => \&_onpriv_start,
            'ident'     => \&_onpub_ident,
            'log'       => \&_onpub_log,
        },
    );
    return $session->ID;
}


#--
# public events

sub _onpub_ident {
    my ($h, $sender, $alias) = @_[HEAP, SENDER, ARG0];
    $h->{alias}{ $sender->ID } = $alias;
}

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
    my ($k, $h, $args) = @_[KERNEL, HEAP, ARG0];
    my $alias = 'journal';

    $k->alias_set( $alias );

    # FIXME: include format for easier timestamping.
    #my $h->{format} = DateTime::Format::Strptime->new( '%b-%d %T' );

    $k->yield( 'ident', $alias );               # register to journal
    $k->post ( 'main', 'rendezvous', $alias );  # signal main that we're started
    $k->yield( 'log',  "start complete\n" );    # logging
}

#--
# private subs


1;
__END__
