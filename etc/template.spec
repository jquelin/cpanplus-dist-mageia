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
BuildRequires:	perl-devel
DISTBUILDREQUIRES

BuildArch: noarch

%description
DISTDESCR

%prep
%setup -q -n %{realname}-%{version} 

%build
yes | %{__perl} Makefile.PL -n INSTALLDIRS=vendor
%make

%check
make test

%install
rm -rf $RPM_BUILD_ROOT
%makeinstall_std

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
DISTDOC
%{_mandir}/man3/*
%perl_vendorlib
DISTEXTRA


%changelog
