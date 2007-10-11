#
# This file is part of Audio::MPD
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#

package CPAN2Mdv::Cooker;

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

    my $pkgname = $dist->pkgname;
    my $vers    = $dist->version;
    $k->post( 'journal', 'log', "task: $pkgname-$vers\n" );

    foreach my $fh ( $h->{mainfh}, $h->{contribfh} ) {
        seek $fh, 0, 0; # reset file handler
        LINE:
        while ( defined(my $line = <$fh>) ) {
            next LINE unless $line =~ /$pkgname-$vers/;

            # found rpm
            chomp $line;
            my $pkg = ( split /\s+/, $line )[-1];

            my $repository = $fh == $h->{mainfh} ? 'main' : 'contrib';
            $k->post( 'journal', 'log', "hold: $repository/$pkg\n" );
            my $url = $h->{conf}{cooker}{$repository} . "/$pkg";

            # download
            my $path = $h->{conf}{general}{cache} . "/rpms/$pkg";
            system( "curl --silent --output $path $url" );
            # FIXME: poco-c-ftp
            # FIXME: check if already downloaded

            $dist->rpm($path);
            $k->post( 'journal', 'log', "done: $path\n" );
            $k->post( 'main', 'need_install', $dist );
            return;
        }
    }

    $k->post( 'journal', 'log', "done: no match\n" );
    $k->post( 'main', 'cooker_done', $dist );
}


#--
# private events

sub _onpriv_start {
    my ($k, $h, $args) = @_[KERNEL, HEAP, ARG0];
    my $alias = 'cooker';

    # store config.
    $h->{conf}  = $args;
    # FIXME: download+update at given freq
    my $ftpmain = $h->{conf}{general}{cache} . '/cooker-main.txt';
    open my $mainfh, '<', $ftpmain or die "can't open '$ftpmain': $!";
    $h->{mainfh} = $mainfh;

    my $ftpcontrib = $h->{conf}{general}{cache} . '/cooker-contrib.txt';
    open my $contribfh, '<', $ftpcontrib or die "can't open '$ftpcontrib': $!";
    $h->{contribfh} = $contribfh;

    # set alias and finish startup.
    $k->alias_set( $alias );
    $k->post( 'journal', 'ident',      $alias );       # register to journal
    $k->post( 'main',    'rendezvous', $alias );       # signal main that we're started
    $k->post( 'journal', 'log', "start complete\n" );  # logging
}



1;
__END__
