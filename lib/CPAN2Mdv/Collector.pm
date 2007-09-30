#
#
#

package CPAN2Mdv::Collector;

use strict;
use warnings;

use HTML::TreeBuilder;
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
    my $name = $dist->name;

    $k->post( 'journal', 'log', "task: $name\n" );

    # fetch information
    my $pkgpage = "http://search.cpan.org/dist/$name/";
    my $html = qx[ curl --silent $pkgpage ];
    # FIXME: use poco-client-http

    my $tree = HTML::TreeBuilder->new_from_content($html);

    # version
    my $vers = $tree->look_down( _tag => 'td', class=>'cell')->as_trimmed_text;
    $vers =~ s/^$name-//;
    $dist->version($vers);

    # url
    my $url = $tree->look_down( _tag => 'a', sub {$_[0]->as_text eq
            'Download' })->attr('href');
    $url = "http://search.cpan.org$url";
    $dist->url($url);

    # FIXME: summary, license, description

    $tree->delete;

    $k->post( 'journal', 'log', "done: $name-$vers\n" );
    $k->post( 'main', 'collector_done', $dist );
}


#--
# private events

sub _onpriv_start {
    my ($k, $h, $args) = @_[KERNEL, HEAP, ARG0];
    my $alias = 'collector';

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
