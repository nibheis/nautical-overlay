# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION=""
HOMEPAGE=""
SRC_URI=""

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm ~arm64"
IUSE=""

DEPEND="
	dev-python/bmp280-python[${PYTHON_USEDEP}]
	dev-python/pynmea2[${PYTHON_USEDEP}]"

RDEPEND="${DEPEND}"
BDEPEND=""
