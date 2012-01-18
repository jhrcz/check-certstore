Name: 		nagios-plugins-certstore
Version: 	2.5
Release:	0%{?dist}
Summary:	Run nagios-plugins-certstore
BuildArch: 	noarch

Group:		ETN
License:	GPL
#URL:		http://upstream-url.org/path
Source0: 	nagios-plugins-certstore-%{version}.tar.gz
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildRequires:	sed
Requires:	openssl

%description
no description

%prep
%setup -q

%build

%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT


%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%config(noreplace) %attr(644,root,root) /etc/nrpe.d/check_certstore.cfg
/usr/bin/txt-from-jks.sh
/usr/bin/txt-from-pem.sh
/usr/bin/txt-from-p12.sh
/usr/lib64/nagios/plugins/check_certstore
%doc CHANGELOG.txt


%changelog
* Wed Jan 18 2012 <jahor@jhr.cz> 2.5-0
- rpm-ification

