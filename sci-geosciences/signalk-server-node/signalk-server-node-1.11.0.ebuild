# Copyright 2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

EGIT_REPO_URI="https://github.com/SignalK/signalk-server-node.git"

if [[ ${PV} = 9999 ]] ; then
	GIT_ECLASS="git-r3"
fi

inherit ${GIT_ECLASS}

DESCRIPTION="An implementation of a Signal K server for boats"
HOMEPAGE="http://signalk.org"
SRC_URI="https://github.com/SignalK/signalk-server-node/archive/v${PV}.tar.gz -> signalk-server-node-${PV}.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~arm64"
IUSE="+production"

DEPEND="net-libs/nodejs
	dev-db/sqlite"
RDEPEND="${DEPEND}"
BDEPEND=""

src_compile() {
	NPM_INSTALL_OPTS=""

	if use production ; then
		NPM_INSTALL_OPTS="--only=production"
	fi

	npm install "${NPM_INSTALL_OPTS}"
}
