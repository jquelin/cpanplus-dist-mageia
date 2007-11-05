#
# This file is part of CPANPLUS::Dist::Mdv.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#

package CPANPLUS::Dist::Mdv;

use strict;
use warnings;

use base 'CPANPLUS::Dist::Base';

use CPANPLUS::Error; # imported subs: error(), msg()
use File::Basename;
use File::Copy      qw[ copy ];
use File::HomeDir;
use IPC::Cmd        qw[ run can_run ];
use Readonly;

our $VERSION = '0.2.1';

Readonly my $DATA_OFFSET => tell(DATA);
Readonly my $RPMDIR      => File::HomeDir->my_home . '/rpm';


#--
# class methods

#
# my $bool = CPANPLUS::Dist::Mdv->format_available;
#
# Return a boolean indicating whether or not you can use this package to
# create and install modules in your environment.
#
sub format_available {
    # check mandriva release file
    if ( ! -f '/etc/mandriva-release' ) {
        error( 'not on a mandriva system' );
        return;
    }

    my $flag;

    # check rpm tree structure
    if ( ! -d $RPMDIR ) {
        error( 'need to create rpm tree structure in your home' );
        return;
    }
    foreach my $subdir ( qw[ BUILD RPMS SOURCES SPECS SRPMS tmp ] ) {
        my $dir = "$RPMDIR/$subdir";
        next if -d $dir;
        error( "missing directory '$dir'" );
        $flag++;
    }

    # check prereqs
    for my $prog ( qw[ rpm rpmbuild gcc ] ) {
        next if can_run($prog);
        error( "'$prog' is a required program to build mandriva packages" );
        $flag++;
    }

    return not $flag;
}

#--
# public methods

#
# my $bool = $mdv->init;
#
# Sets up the C<CPANPLUS::Dist::Mdv> object for use, and return true if
# everything went fine.
#
sub init {
    my ($self) = @_;
    my $status = $self->status; # an Object::Accessor
    # distname: Foo-Bar
    # distvers: 1.23
    # extra_files: qw[ /bin/foo /usr/bin/bar ] 
    # rpmname:  perl-Foo-Bar
    # rpmpath:  $RPMDIR/RPMS/noarch/perl-Foo-Bar-1.23-1mdv2008.0.noarch.rpm
    # rpmvers:  1
    # srpmpath: $RPMDIR/SRPMS/perl-Foo-Bar-1.23-1mdv2008.0.src.rpm
    # specpath: $RPMDIR/SPECS/perl-Foo-Bar.spec
    $status->mk_accessors(qw[ distname distvers extra_files rpmname rpmpath
        rpmvers srpmpath specpath ]);

    return 1;
}

sub prepare {
    my ($self, %args) = @_;
    my $status = $self->status;               # private hash
    my $module = $self->parent;               # CPANPLUS::Module
    my $intern = $module->parent;             # CPANPLUS::Internals
    my $conf   = $intern->configure_object;   # CPANPLUS::Configure
    my $distmm = $module->status->dist_cpan;  # CPANPLUS::Dist::MM

    # parse args.
    my %opts = (
        force   => $conf->get_conf('force'),  # force rebuild
        perl    => $^X,
        verbose => $conf->get_conf('verbose'),
        %args,
    );

    # dry-run with makemaker: find build prereqs.
    msg( "dry-run prepare with makemaker..." );
    $self->SUPER::prepare( %args );

    # compute & store package information
    my $distname    = $module->package_name;
    $status->distname( $distname );
    my $distvers    = $module->package_version;
    #my $distsummary    = 
    #my $distdescr      = 
    #my $distlicense    =
    my $disturl        = $module->package;
    my @reqs           = sort keys %{ $module->status->prereqs };
    my $distreqs       = join "\n", map { "Requires: perl($_)" } @reqs;
    my $distbreqs      = join "\n", map { "BuildRequires: perl($_)" } @reqs;
    my @docfiles =
        grep { /(README|Change(s|log)|LICENSE|META.yml)$/i }
        map { basename $_ }
        @{ $module->status->files };

    my $rpmname = _mk_pkg_name($distname);
    $status->rpmname( $rpmname );


    # check whether package has been build.
    if ( my $pkg = $self->_has_been_build($rpmname, $distvers) ) {
        my $modname = $module->module;
        msg( "already created package for '$modname' at '$pkg'" );

        if ( not $opts{force} ) {
            msg( "won't re-spec package since --force isn't in use" );
            # c::d::mdv store
            $status->rpmpath($pkg); # store the path of rpm
            # cpanplus api
            $status->prepared(1);
            $status->created(1);
            $status->dist($pkg);
            return $pkg;
            # XXX check if it works
        }

        msg( '--force in use, re-specing anyway' );
        # FIXME: bump rpm version
    } else {
        msg( "writing specfile for '$distname'..." );
    }

    # compute & store path of specfile.
    my $spec = "$RPMDIR/SPECS/$rpmname.spec";
    $status->specpath($spec);

    my $vers = $module->version;

    # writing the spec file.
    seek DATA, $DATA_OFFSET, 0;
    my $specfh;
    if ( not open $specfh, '>', $spec ) {
        error( "can't open '$spec': $!" );
        return;
    }
    while ( defined( my $line = <DATA> ) ) {
        last if $line =~ /^__END__$/;

        $line =~ s/DISTNAME/$distname/;
        $line =~ s/DISTVERS/$distvers/;
        #$line =~ s/DISTSUMMARY/$distsummary/;
        $line =~ s/DISTURL/$disturl/;
        $line =~ s/DISTBUILDREQUIRES/$distbreqs/;
        $line =~ s/DISTREQUIRES/$distreqs/;
        #$line =~ s/DISTDESCR/$distdescr/;
        $line =~ s/DISTDOC/@docfiles ? "%doc @docfiles" : ''/e;
        $line =~ s/DISTEXTRA/join( "\n", @{ $status->extra_files || [] })/e;

        print $specfh $line;
    }
    close $specfh;

    # copy package.
    my $basename = basename $module->status->fetch;
    my $tarball = "$RPMDIR/SOURCES/$basename";
    copy( $module->status->fetch, $tarball );

    msg( "specfile for '$distname' written" );
    # return success
    $status->prepared(1);
    return 1;
}


sub create {
    my ($self, %args) = @_;
    my $status = $self->status;               # private hash
    my $module = $self->parent;               # CPANPLUS::Module
    my $intern = $module->parent;             # CPANPLUS::Internals
    my $conf   = $intern->configure_object;   # CPANPLUS::Configure
    my $distmm = $module->status->dist_cpan;  # CPANPLUS::Dist::MM

    # parse args.
    my %opts = (
        force   => $conf->get_conf('force'),  # force rebuild
        perl    => $^X,
        verbose => $conf->get_conf('verbose'),
        %args,
    );

    # check if we need to rebuild package.
    if ( $status->created && defined $status->dist ) {
        if ( not $opts{force} ) {
            msg( "won't re-build package since --force isn't in use" );
            return $status->dist;
        }
        msg( '--force in use, re-building anyway' );
    }

    RPMBUILD: {
        # dry-run with makemaker: handle prereqs.
        msg( 'dry-run build with makemaker...' );
        $self->SUPER::create( %args );


        my $spec     = $status->specpath;
        my $distname = $status->distname;
        my $rpmname  = $status->rpmname;

        msg( "building '$distname' from specfile..." );

        # dry-run, to see if we forgot some files
        my ($buffer, $success);
        DRYRUN: {
            local $ENV{LC_ALL} = 'C';
            $success = run(
                command => "rpmbuild -ba --quiet $spec",
                verbose => $opts{verbose},
                buffer  => \$buffer,
            );
        }

        # check if the dry-run finished correctly
        if ( $success ) {
            my ($rpm)  = (sort glob "$RPMDIR/RPMS/*/$rpmname-*.rpm")[-1];
            my ($srpm) = (sort glob "$RPMDIR/SRPMS/$rpmname-*.src.rpm")[-1];
            msg( "rpm created successfully: $rpm" );
            msg( "srpm available: $srpm" );
            # c::d::mdv store
            $status->rpmpath($rpm);
            $status->srpmpath($srpm);
            # cpanplus api
            $status->created(1);
            $status->dist($rpm);
            return $rpm;
        }

        # unknown error, aborting.
        if ( not $buffer =~ /^\s+Installed .but unpackaged. file.s. found:\n(.*)\z/ms ) {
            error( "failed to create mandriva package for '$distname': $buffer" );
            # cpanplus api
            $status->created(0);
            return;
        }

        # additional files to be packaged
        msg( "extra files installed, fixing spec file" );
        my $files = $1;
        $files =~ s/^\s+//mg; # remove spaces
        my @files = split /\n/, $files;
        $status->extra_files( \@files );
        $self->prepare( %opts, force => 1 );
        msg( 'restarting build phase' );
        redo RPMBUILD;
    }
}

sub install {
    my ($self, %args) = @_;
    my $rpm = $self->status->rpm;
    error( "installing $rpm" );
    die;
    #$dist->status->installed
}



#--
# private methods

#
# my $bool = $self->_has_been_build;
#
# return true if there's already a package build for this module.
# 
sub _has_been_build {
    my ($self, $name, $vers) = @_;
    my $pkg = ( sort glob "$RPMDIR/RPMS/*/$name-$vers-*.rpm" )[-1];
    return $pkg;
    # FIXME: should we check cooker?
}


#--
# private subs

#
# my $name = _mk_pkg_name($dist);
#
# given a distribution name, return the name of the mandriva rpm
# package. in most cases, it will be the same, but some pakcage name
# will be too long as a rpm name: we'll have to cut it.
#
sub _mk_pkg_name {
    my ($dist) = @_;
    my $name = 'perl-' . $dist;
    return $name;
}


1;

__DATA__

%define realname   DISTNAME

Name:		perl-%{realname}
Version:    DISTVERS
Release:    %mkrel 1
License:	GPL or Artistic
Group:		Development/Perl
Summary:    DISTSUMMARY
Source0:    DISTURL
Url:		http://search.cpan.org/dist/%{realname}
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildRequires: perl-devel
DISTBUILDREQUIRES
DISTREQUIRES

BuildArch: noarch

%description
DISTDESCR

%prep
%setup -q -n %{realname}-%{version} 

%build
yes | %{__perl} Makefile.PL -n INSTALLDIRS=vendor
%make

%check
#make test

%install
rm -rf $RPM_BUILD_ROOT
%makeinstall_std

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
DISTDOC
%{_mandir}
%perl_vendorlib
DISTEXTRA


%changelog

__END__


=head1 NAME

CPANPLUS::Dist::Mdv - a cpanplus backend to build mandriva rpms



=head1 SYNOPSYS

    cpan2dist --format=CPANPLUS::Dist::Mdv Some::Random::Package



=head1 DESCRIPTION

CPANPLUS::Dist::Mdv is a distribution class to create mandriva packages
from CPAN modules, and all its dependencies. This allows you to have
the most recent copies of CPAN modules installed, using your package
manager of choice, but without having to wait for central repositories
to be updated.

You can either install them using the API provided in this package, or
manually via rpm.

Some of the bleading edge CPAN modules have already been turned into
mandriva packages for you, and you can make use of them by adding the
cooker repositories (main & contrib).

Note that these packages are built automatically from CPAN and are
assumed to have the same license as perl and come without support.
Please always refer to the original CPAN package if you have questions.



=head1 CLASS METHODS

=head2 $bool = CPANPLUS::Dist::Mdv->format_available;

Return a boolean indicating whether or not you can use this package to
create and install modules in your environment.

It will verify if you are on a mandriva system, and if you have all the
necessary components avialable to build your own mandriva packages. You
will need at least these dependencies installed: C<rpm>, C<rpmbuild> and
C<gcc>.



=head1 PUBLIC METHODS

=head2 $bool = $mdv->init;

Sets up the C<CPANPLUS::Dist::Mdv> object for use. Effectively creates
all the needed status accessors.

Called automatically whenever you create a new C<CPANPLUS::Dist> object.


=head2 $bool = $mdv->prepare;

Prepares a distribution for creation. This means it will create the rpm
spec file needed to build the rpm and source rpm. This will also satisfy
any prerequisites the module may have.

Returns true on success and false on failure.

You may then call C<< $mdv->create >> on the object to create the rpm
from the spec file, and then C<< $mdv->install >> on the object to
actually install it.


=head2 $bool = $mdv->create;

Builds the rpm file from the spec file created during the C<create()>
step.

Returns true on success and false on failure.

You may then call C<< $mdv->install >> on the object to actually install it.


=head2 $bool = $mdv->install;

Installs the rpm using C<rpm -U>.

B</!\ Work in progress: not implemented.>

Returns true on success and false on failure



=head1 TODO

There are no TODOs of a technical nature currently, merely of an
administrative one;

=over

=item o Scan for proper license

Right now we assume that the license of every module is C<the same
as perl itself>. Although correct in almost all cases, it should 
really be probed rather than assumed.


=item o Long description

Right now we provided the description as given by the module in it's
meta data. However, not all modules provide this meta data and rather
than scanning the files in the package for it, we simply default to the
name of the module.


=back



=head1 BUGS

Please report any bugs or feature requests to C<< < cpanplus-dist-mdv at
rt.cpan.org> >>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CPANPLUS-Dist-Mdv>.  I
will be notified, and then you'll automatically be notified of progress
on your bug as I make changes.



=head1 SEE ALSO

L<CPANPLUS::Backend>, L<CPANPLUS::Module>, L<CPANPLUS::Dist>,
C<cpan2dist>, C<rpm>, C<urpmi>


C<CPANPLUS::Dist::Mdv> development takes place on
L<http://cpanplus-dist-mdv.googlecode.com> - feel free to join us.


You can also look for information on this module at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/CPANPLUS-Dist-Mdv>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/CPANPLUS-Dist-Mdv>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=CPANPLUS-Dist-Mdv>

=back



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2007 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

