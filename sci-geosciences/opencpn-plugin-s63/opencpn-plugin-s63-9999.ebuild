# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

WX_GTK_VER="3.0-gtk3"
MY_PN="oesenc_pi"
if [[ ${PV} == "9999" ]] ; then
	EGIT_REPO_URI="https://github.com/bdbcat/s63_pi.git"
	inherit git-r3 cmake-utils wxwidgets
else
	SRC_URI="https://github.com/mschiff/${MY_PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	inherit cmake-utils wxwidgets
	S="${WORKDIR}/${MY_PN}-${PV}"
fi

DESCRIPTION="S63 Plugin for OpenCPN"
HOMEPAGE="https://github.com/bdbcat/s63_pi"
KEYWORDS="~amd64 ~x86"

LICENSE=""
SLOT="0"
IUSE=""

RDEPEND="
	x11-libs/wxGTK:${WX_GTK_VER}
	>=sci-geosciences/opencpn-5.0.0
	sys-devel/gettext
"
DEPEND="${RDEPEND}"

PATCHES=(
	"${FILESDIR}/lib.patch"
)

src_prepare() {
	setup-wxwidgets
	cmake-utils_src_prepare
}
