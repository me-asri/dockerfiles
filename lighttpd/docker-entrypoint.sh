#!/bin/sh
# shellcheck shell=dash

readonly CONF_DIR='/etc/lighttpd'

info() {
	echo "[*] $1" >&2
}

error() {
	echo "[!] $1" >&2
	exit 1
}

gen_conf_tls() {
	local cert_file="${CONF_DIR}/tls_cert.pem"
	local priv_file="${CONF_DIR}/tls_privkey.pem"

	install -o root -g root -m 600 /dev/null "${cert_file}"
	install -o root -g root -m 600 /dev/null "${priv_file}"

	if [ -z "${LIGHTTPD_TLS_CERT}" ]; then
		error 'LIGHTTPD_TLS_CERT environment variable not specified' >&2
	fi
	if ! echo "${LIGHTTPD_TLS_CERT}" | base64 -d -w0 > "${cert_file}"; then
		error 'Failed to decode TLS certificate'
	fi

	if [ -z "${LIGHTTPD_TLS_PRIVKEY}" ]; then
		error 'LIGHTTPD_TLS_PRIVKEY environment variable not specified' >&2
	fi
	if ! echo "${LIGHTTPD_TLS_PRIVKEY}" | base64 -d -w0 > "${priv_file}"; then
		error 'Failed to decode TLS private key'
	fi

	cat <<- EOF
		server.modules += ( "mod_openssl" )

		\$SERVER["socket"] == ":${LIGHTTPD_TLS_PORT}" {
			ssl.engine = "enable"

			ssl.pemfile = "${cert_file}"
			ssl.privkey = "${priv_file}"
		}
	EOF
}

gen_conf_vhost() {
	cat <<- EOF
		server.modules += ( "mod_evhost" )

		evhost.path-pattern = server_root + "/%_/htdocs/"
	EOF
}

gen_conf() {
	if [ "${LIGHTTPD_ENABLE_TLS}" = '1' ] || [ "${LIGHTTPD_ENABLE_TLS}" = 'true' ]; then
		info 'TLS enabled'
		gen_conf_tls
	fi
	if [ "${LIGHTTPD_ENABLE_VHOST}" = '1' ] || [ "${LIGHTTPD_ENABLE_VHOST}" = 'true' ]; then
		info 'VHost enabled'
		gen_conf_vhost
	fi
}

run_lighttpd() {
	exec 5>&1
	chown "${LIGHTTPD_USER}:${LIGHTTPD_GROUP}" /dev/fd/5

	exec /opt/lighttpd/sbin/lighttpd -D -f /etc/lighttpd/lighttpd.conf "$@"   
}

main() {
	local cmd="$1"
	shift

	case "${cmd}" in
	'lighttpd')
		run_lighttpd "$@"
		;;
	'conf')
		gen_conf "$@"
		;;
	*)
		error "Unknown command ${cmd}"
		;;
	esac
}

main "$@"