#
#
#

package CPAN2Mdv::Downloader;

use strict;
use warnings;

use File::Basename;
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

    my $url = $dist->url;
    $k->post( 'journal', 'log', "task: $url\n" );

    my $basename = basename($url);
    my $path = "$ENV{HOME}/rpm/SOURCES/$basename";
    $dist->path($path);

    if ( -r $path ) {
        # file already exists
        $k->post( 'journal', 'log', "task: $path\n" );
        $k->post( 'main', 'downloader_done', $dist );
        return;
    }

    # download
    # FIXME: poco-c-http
    system( "curl --silent --location --output $path $url" );
    $k->post( 'journal', 'log', "task: $path\n" );
    $k->post( 'main', 'downloader_done', $dist );
}


#--
# private events

sub _onpriv_start {
    my ($k, $h, $args) = @_[KERNEL, HEAP, ARG0];
    my $alias = 'downloader';

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
