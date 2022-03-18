# Deprecation Shims

usp_rcload() {
	_usp_log warn "$(_usp_color warn)DEPRECATED: $(_usp_color)usp_rcload; use usp-source instead"
	usp-source "$@"
}

usp_path_prepend() {
	_usp_log warn "$(_usp_color warn)DEPRECATED: $(_usp_color)usp_path_prepend"
	_usp_path_prepend "$@"
}

usp_path_append() {
	_usp_log warn "$(_usp_color warn)DEPRECATED: $(_usp_color)usp_path_append"
	_usp_path_append "$@"
}

usp_clobbercheck() {
	_usp_log warn "$(_usp_color warn)DEPRECATED: $(_usp_color)usp_clobbercheck; use usp-clobber-check"
	_usp_clobbercheck "$@"
}

usp_is_linux() {
	_usp_log warn "$(_usp_color warn)DEPRECATED: $(_usp_color)usp_is_linux; use usp-is-platform instead"
	[[ $(_usp_get_uname) = 'linux' ]] && return 0
	return 1
}

usp_is_macos() {
	_usp_log warn "$(_usp_color warn)DEPRECATED: $(_usp_color)usp_is_macos; use usp-is-platform instead"
	[[ $(_usp_get_uname) = 'darwin' ]] && return 0
	return 1
}

usp_log_debug() {
	_usp_log warn "$(_usp_color warn)DEPRECATED: $(_usp_color)usp_log_debug; use usp-log instead"
	_usp_log "$@"
}

usp-source() {
	_usp_log warn "$(_usp_color warn)DEPRECATED: $(_usp_color)usp-source; use 'usp source' instead"
	_usp_source "$@"
}

usp-log() {
	_usp_log warn "$(_usp_color warn)DEPRECATED: $(_usp_color)usp-log; use 'usp log' instead"
	_usp_log "$@"
}

usp-clobber-check() {
	_usp_log warn "$(_usp_color warn)DEPRECATED: $(_usp_color)usp-clobber-check; use 'usp clobbertest' instead"
	_usp_clobbercheck "$@"
}

usp-is-platform() {
	_usp_log warn "$(_usp_color warn)DEPRECATED: $(_usp_color)usp-is-platform; use 'usp is-platform' instead"
	_usp_is_platform "$@"
}
