#
# This file is part of CPAN2Mdv.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#

package CPAN2Mdv::Uploader;

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
# public events

sub _onpub_task {
    my ($k, $h, $dist) = @_[KERNEL, HEAP, ARG0];

    my $srpm = $dist->srpm;
    return unless defined $srpm;
    $k->post( 'journal', 'log', "task: $srpm\n" );

    my $incoming = $h->{conf}{uploader}{incoming};
    system( "curl --silent --upload-file $srpm $incoming/" );
    # FIXME: poco-c-ftp

    $k->post( 'journal', 'log', "done: pushed\n" );
    $k->post( 'main', 'uploader_done', $dist );
}


#--
# private events

sub _onpriv_start {
    my ($k, $h, $args) = @_[KERNEL, HEAP, ARG0];
    my $alias = 'uploader';

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
