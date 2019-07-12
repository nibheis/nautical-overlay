# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DISTUTILS_OPTIONAL=1
PYTHON_COMPAT=( python3_{4,5,6,7} )
SCONS_MIN_VERSION="1.2.1"

inherit eutils udev user multilib distutils-r1 scons-utils toolchain-funcs python-r1

if [[ ${PV} == "9999" ]] ; then
	EGIT_REPO_URI="https://git.savannah.gnu.org/git/gpsd.git"
	EGIT_CLONE_TYPE="shallow"
	inherit git-r3
else
	SRC_URI="mirror://nongnu/${PN}/${P}.tar.gz"
	KEYWORDS="~amd64 ~arm ~ppc ~ppc64 ~x86"
fi

DESCRIPTION="GPS daemon and library for USB/serial GPS devices and GPS/mapping clients"
HOMEPAGE="http://catb.org/gpsd/"

LICENSE="BSD"
SLOT="0/23"

GPSD_PROTOCOLS=(
	aivdm ashtech earthmate evermore fury fv18 garmin garmintxt geostar
	gpsclock greis isync itrax mtk3301 navcom nmea0183 nmea2000 ntrip oceanserver
	oncore passthrough rtcm104v2 rtcm104v3 sirf skytraq superstar2 tnt
	tripmate tsip ublox
)
IUSE_GPSD_PROTOCOLS=${GPSD_PROTOCOLS[@]/#/gpsd_protocols_}
IUSE="${IUSE_GPSD_PROTOCOLS} bluetooth +cxx dbus debug ipv6 latency_timing ncurses ntp python qt5 +shm +sockets static systemd test udev usb"
REQUIRED_USE="
	gpsd_protocols_nmea2000? ( gpsd_protocols_aivdm )
	python? ( ${PYTHON_REQUIRED_USE} )
	qt5? ( cxx )"

RDEPEND="
	>=net-misc/pps-tools-0.0.20120407
	bluetooth? ( net-wireless/bluez )
	dbus? (
		sys-apps/dbus
		dev-libs/dbus-glib
	)
	ncurses? ( sys-libs/ncurses:= )
	ntp? ( || (
		net-misc/ntp
		net-misc/ntpsec
		net-misc/chrony
	) )
	qt5? (
		dev-qt/qtcore:5
		dev-qt/qtnetwork:5
	)
	python? ( ${PYTHON_DEPS} )
	usb? ( virtual/libusb:1 )
	dev-python/pyserial
	net-misc/pps-tools
	virtual/libusb
	sys-libs/libcap"
DEPEND="${RDEPEND}
	virtual/pkgconfig
	test? ( sys-devel/bc )"

# xml packages are for man page generation
if [[ ${PV} == *9999* ]] ; then
	DEPEND+="
		app-text/xmlto
		app-text/asciidoc"
fi

src_prepare() {
	default

	# Make sure our list matches the source.
	local src_protocols=$(echo $(
		sed -n '/# GPS protocols/,/# Time service/{s:#.*::;s:[(",]::g;p}' "${S}"/SConstruct | awk '{print $1}' | LC_ALL=C sort
	) )
	if [[ ${src_protocols} != ${GPSD_PROTOCOLS[*]} ]] ; then
		eerror "Detected protocols: ${src_protocols}"
		eerror "Ebuild protocols:   ${GPSD_PROTOCOLS[*]}"
		die "please sync ebuild & source"
	fi

	#epatch "${FILESDIR}"/${P}-do_not_rm_library.patch

	# Avoid useless -L paths to the install dir
	sed -i \
		-e 's:\<STAGING_PREFIX\>:SYSROOT:g' \
		SConstruct || die

	use python && distutils-r1_src_prepare
}

python_prepare_all() {
	python_setup
	python_export
	#python_export_best
	# Extract python info out of SConstruct so we can use saner distribute
	pyvar() { sed -n "/^ *$1 *=/s:.*= *::p" SConstruct ; }
	local pybins=$(pyvar python_progs | tail -1)
	local pysrcs=$(sed -n '/^ *python_extensions = {/,/}/{s:^ *::;s:os[.]sep:"/":g;p}' SConstruct)
	local packet=$("${PYTHON}" -c "${pysrcs}; print(python_extensions['gps/packet'])")
	local client=$("${PYTHON}" -c "${pysrcs}; print(python_extensions['gps/clienthelpers'])")
	sed \
		-e "s|@VERSION@|$(pyvar gpsd_version)|" \
		-e "s|@URL@|$(pyvar website)|" \
		-e "s|@EMAIL@|$(pyvar devmail)|" \
		-e "s|@SCRIPTS@|${pybins}|" \
		-e "s|@GPS_PACKET_SOURCES@|${packet}|" \
		-e "s|@GPS_CLIENT_SOURCES@|${client}|" \
		-e "s|@SCRIPTS@|${pybins}|" \
		"${FILESDIR}"/${PN}-3.3-setup.py > setup.py || die
	distutils-r1_python_prepare_all
}

src_configure() {
	prefix_var="${EPREFIX}/usr"
	libdir_var="${prefix_var}/$(get_libdir)"
	MYSCONS=(
		prefix="${EPREFIX}/usr"
		#libdir="${prefix}/$(get_libdir)"
		libdir="${libdir_var}"
		python_libdir="$(python_get_sitedir)"
		udevdir="$(get_udevdir)"
		chrpath=False
		gpsd_user=gpsd
		gpsd_group=uucp
		nostrip=True
		python=True
		manbuild=True
		shared=$(usex !static True False)
		bluez=$(usex bluetooth True False)
		libgpsmm=$(usex cxx True False)
		clientdebug=$(usex debug True False)
		dbus_export=$(usex dbus True False)
		ipv6=$(usex ipv6 True Flase)
		timing=$(usex latency_timing True False)
		ncurses=$(usex ncurses True False)
		ntpshm=$(usex ntp True False)
		pps=$(usex ntp True False)
		qt=$(usex qt5 True False)
		shm_export=$(usex shm True False)
		socket_export=$(usex sockets True False)
		usb=$(usex usb True False)
		systemd=$(usex systemd True False)
	)

	use qt5 && MYSCONS+=( qt_versioned=5 )

	# enable specified protocols
	local protocol
	for protocol in ${GPSD_PROTOCOLS[@]} ; do
		MYSCONS+=( ${protocol}=$(usex gpsd_protocols_${protocol} True False) )
	done
}

src_compile() {
	export CHRPATH=
	tc-export CC CXX PKG_CONFIG
	export SHLINKFLAGS=${LDFLAGS} LINKFLAGS=${LDFLAGS}
	escons "${MYSCONS[@]}"

	use python && distutils-r1_src_compile
}

src_install() {
	DESTDIR="${D}" escons install $(usex udev udev-install "")

	newconfd "${FILESDIR}"/gpsd.conf-2 gpsd
	newinitd "${FILESDIR}"/gpsd.init-2 gpsd

	if use python ; then
		distutils-r1_src_install
		# Delete all X related packages if user doesn't want them
		#if ! use X && [[ -f "${ED%/}"/usr/bin/xgps ]]; then
		#	rm "${ED%/}"/usr/bin/xgps* || die
		#fi
	fi

}

pkg_preinst() {
	# Run the gpsd daemon as gpsd and group uucp; create it here
	# as it doesn't seem to be needed during compile/install ...
	enewuser gpsd -1 -1 -1 "uucp"
}