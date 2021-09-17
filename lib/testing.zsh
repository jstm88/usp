# This file contains USP functions that are only used for testing
# It is not normally loaded except during development.

# Print a list of available colors and keys
_usp_color_test() {
	local keys=(${(@k)_usp_color_table})
	local col_key
	for col_key in $keys; do
		echo "$(_usp_color $col_key)COLOR TEST: $col_key$(_usp_color nc)"
	done
}

# Test the various log options
_usp_log_test() {
	local PREV_DEBUG=$USP_DEBUG
	echo "\$USP_DEBUG is currently set to $PREV_DEBUG"
	export USP_DEBUG=${_usp_debug_map[print]} # none
	echo "\$USP_DEBUG=none (should show nothing except the print)"
	_usp_log print "$(_usp_color ok)This print message should be visible"
	_usp_log err "$(_usp_color err)This message should NOT be visible"
	_usp_log warn "$(_usp_color err)This message should NOT be visible"
	_usp_log info "$(_usp_color err)This message should NOT be visible"
	export USP_DEBUG=${_usp_debug_map[err]} # error
	echo "\$USP_DEBUG=error (should show error)"
	_usp_log print "$(_usp_color ok)This print message should be visible"
	_usp_log err "$(_usp_color ok)This message should be visible"
	_usp_log warn "$(_usp_color err)This message should NOT be visible"
	_usp_log info "$(_usp_color err)This message should NOT be visible"
	export USP_DEBUG=${_usp_debug_map[warn]} # warn
	echo "\$USP_DEBUG=warn (should show error & warn)"
	_usp_log print "$(_usp_color ok)This print message should be visible"
	_usp_log err "$(_usp_color ok)This message should be visible"
	_usp_log warn "$(_usp_color ok)This message should be visible"
	_usp_log info "$(_usp_color err)This message should NOT be visible"
	export USP_DEBUG=${_usp_debug_map[info]} # info
	echo "\$USP_DEBUG=warn (should show everything)"
	_usp_log print "$(_usp_color ok)This print message should be visible"
	_usp_log err "$(_usp_color ok)This message should be visible"
	_usp_log warn "$(_usp_color ok)This message should be visible"
	_usp_log info "$(_usp_color ok)This message should be visible"
	echo "Restoring \$USP_DEBUG to its previous value of $PREV_DEBUG"
	export USP_DEBUG=$PREV_DEBUG
}
