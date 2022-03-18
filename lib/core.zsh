# USP Internal Helper Functions

typeset -A _usp_color_table=(
	[nc]='0'
	[head]='1;36'   # bold cyan
	[strong]='1;37' # bold white
	[weak]='2'      # gray
	[err]='0;31'    # red
	[warn]='0;33'   # orange
	[info]='0;36'   # cyan
	[ok]='0;32'     # green
)

# Get the color for a given key
# Return "no color" code if no parameter is given
# Return nothing if parameter is invalid
_usp_color() {
	local cprefix='\e[' # \033[]
	local col_str=${1:='nc'}
	(( ! ${+_usp_color_table[${col_str:l}]} )) && return 1
	local col_code="${cprefix}${_usp_color_table[${col_str:l}]}m"
	echo $col_code
}

# Log at the specified level
# Anything at or more severe than the
# level of $USP_DEBUG will get through
_usp_log() {
	if [[ $# -eq 1 ]]; then
		_usp_log info "$1"
		return 0
	elif [[ $# -eq 0 ]]; then
		_usp_log err "USP log called with no arguments."
		return 1
	fi

	local log_val=${_usp_debug_map[$1]}
	if [[ ! -n "$log_val" ]]; then
		echo "USP log called with improper type $1"
		return 1
	fi

	if [[ ${log_val} -le ${_usp_debug_map[$USP_DEBUG]} ]]; then
		echo "${USP_LOG_PREFIX}${2}$(_usp_color)"
	fi
}

# Strip only the home directory from the beginning of a path
_usp_strip_homedir() {
	echo "${1/#$HOME/$(_usp_color weak)~$(_usp_color)}"
}

# Clean up a path by replacing anything that can be replaced, including the home dir
# Consider allowing this to be disabled by a setting
_usp_clean_path() {
	local CPATH="$1"
	CPATH="${CPATH/#$DOTFILES_ROOT/$(_usp_color weak)\$DOTFILES_ROOT$(_usp_color)}"
	CPATH="${CPATH/#$USP_ROOT/$(_usp_color weak)\$USP_ROOT$(_usp_color)}"
	CPATH="${CPATH/#$PROFILE_ROOT/$(_usp_color weak)\$PROFILE_ROOT$(_usp_color)}"
	CPATH=$(_usp_strip_homedir $CPATH)
	echo "$CPATH"
}

# Load an RC file and log its result
_usp_source() {
	local quiet=0
	if [[ "$1" == "-q" ]]; then
		quiet=1
		shift
	fi
	FILE="$1"
	if [[ -f "$FILE" ]]; then
		_usp_log info "$(_usp_color ok)Loading $(_usp_color)$(_usp_clean_path $FILE)"
		source $FILE
	else
		((quiet)) || _usp_log warn "$(_usp_color warn)No file $(_usp_color)$(_usp_clean_path $FILE)"
	fi
}

# Append an element to the $PATH variable
# In ZSH, $PATH is tied to the $path array
# To add to end, `path+=(~/foo)`
# To add to beginning, `path=(~/foo "$path[@]")` or `path[1,0]=~/foo`
# As long as `typeset -U path` is used, items will be unique
# Passing -q will quiet the "Path does not exist" warning
_usp_path_prepend() {
	local quiet=0
	if [[ "$1" == "-q" ]]; then
		quiet=1
		shift
	fi
	if [[ -d "$1" ]]; then
		path[1,0]="$1"
		_usp_log info "$(_usp_color info)Prepended to PATH: $(_usp_color)$(_usp_clean_path $1)"
	else
		((quiet)) || _usp_log warn "$(_usp_color warn)Path does not exist: $(_usp_color)$(_usp_clean_path $1)"
	fi
}

_usp_path_append() {
	local quiet=0
	if [[ "$1" == "-q" ]]; then
		quiet=1
		shift
	fi
	if [[ -d "$1" ]]; then
		path+="$1"
		_usp_log info "$(_usp_color info)Appended to PATH: $(_usp_color)$(_usp_clean_path $1)"
	else
		((quiet)) || _usp_log warn "$(_usp_color warn)Path does not exist: $(_usp_color)$(_usp_clean_path $1)"
	fi
}

_usp_plugin_path_prepend() {
	if [[ -d "$1" ]]; then
		_usp_plugin_path[1,0]="$1"
		_usp_log info "$(_usp_color info)Prepended to plugin path: $(_usp_color)$(_usp_clean_path $1)"
	else
		_usp_log warn "$(_usp_color warn)Path does not exist: $(_usp_color)$(_usp_clean_path $1)"
	fi
}
_usp_plugin_path_append() {
	if [[ -d "$1" ]]; then
		_usp_plugin_path+="$1"
		_usp_log info "$(_usp_color info)Appended to plugin path: $(_usp_color)$(_usp_clean_path $1)"
	else
		_usp_log warn "$(_usp_color warn)Path does not exist: $(_usp_color)$(_usp_clean_path $1)"
	fi
}

# Get the system uname lowercased
_usp_get_uname() {
	UN=$(uname -s)
	echo ${UN:l}
}

# Get the system hostname lowercased
_usp_get_hostname() {
	HN=$(hostname -s)
	echo ${HN:l}
}

# Check if the function, variable, or alias we're about
# to add will clobber an existing one.
# Usage: usp_clobbercheck NAME [TYPE]
# where TYPE = func, alias, var
_usp_clobbercheck() {
	[[ -n $1 ]] || return 0
	local _dbg_out() {
		_usp_log err "$(_usp_color err)Warning:$(_usp_color) \"$1\" will clobber an existing $2"
	}
	local _check() {
		if [[ "$2" == "func" && ${(k)functions[(Ie)$1]} ]]; then
			_dbg_out "$1" "$2"
			return 1
		fi
		if [[ "$2" == "alias" && ${(k)aliases[(Ie)$1]} ]]; then
			_dbg_out "$1" "$2"
			return 1
		fi
		if [[ "$2" == "var" && ${(k)parameters[(Ie)$1]} ]]; then
			_dbg_out "$1" "$2"
			return 1
		fi
		return 0
	}
	local types=("func" "alias" "var")
	if [[ -n $2 ]]; then
		if (( $types[(Ie)$2] )); then
			_check "$1" "$2"
			return $?
		else
			echo "Invalid type"
			return 1
		fi
	fi
	for type in $types; do
		_check "$1" "$type"
		local RES=$?
		[[ $RES -ne 0 ]] && return $RES
	done
	return 0
}

# Reload the shell
# If the debug option is specified, set debug to info before reloading
_usp_reload() {
	if [[ $# -gt 0 && "${1}" == '-d' || "${1}" == '--debug' ]]; then
		export USP_DEBUG_OVERRIDE=info
		exec zsh
	else
		exec zsh
	fi
}

# Update the profile Git repo
_usp_update() {
	local PREV_CWD=`pwd`
	cd "${PROFILE_ROOT}"
	git fetch
	git pull --ff-only
	cd "${PREV_CWD}"
	usp reload
}

# Set or display the debug level
# If an argument is provided, set
# If no argument is provided, print
_usp_cmd_debug() {
	if [[ $# -gt 0 ]]; then
		local new_level=${1:l}
		if (( ${+_usp_debug_map[$new_level]} )); then
			export USP_DEBUG="$new_level"
			return
		else
			echo "Invalid debug level \"$new_level\""
		fi
	else
		echo "Current debug level: \"$USP_DEBUG\""
	fi
}

# Optional: cleanup the global functions once the rc file is loaded
# usp_rc_functions_cleanup() {
# 	unset -f usp_log_debug
# 	unset -f usp_rcload
# 	unset -f usp_path_prepend
# 	unset -f usp_path_append
# 	unset -f usp_get_uname
# 	unset -f usp_is_linux
# 	unset -f usp_is_macos
# 	unset -f usp_get_hostname
# 	unset -f usp_rc_functions_cleanup
# 	unset -f usp_clobbercheck
# }



# Timing Notes
# If the `gdate` function is not installed, we only get timing to 1s precision
# This isn't enough. If we detect this, we simply warn that timing isn't available.

# Get current time in milliseconds
_usp_get_millis() {
	local millis
	if hash gdate 2>/dev/null; then
		millis=$(gdate +%s%3N)
	else
		millis=$(date +%s%3N)
	fi
	# echo "${millis//3N/000}"
	echo "${millis}"
}

# _usp_is_time_ms_accurate() {
# 	if [[ "$1" == *3N ]]; then
# 		echo 0
# 	fi
# 	echo 1
# }

# if [[ $(_usp_is_time_ms_accurate $USP_LOAD_START_MS) == 1 ]]; then
# 	echo "Accurate time!"
# else
# 	echo "Inaccurate time"
# fi

# if [[ "$USP_LOAD_START_MS" == *3N ]]; then
# 	echo "3N detected"
# 	USP_LOAD_START_MS="${USP_LOAD_START_MS//3N/000}"
# fi


# Get elapsed time between two values
# _usp_timing_get_elapsed_time() {
# 	if ( _usp_is_time_ms_accurate $1 ); then
# 		echo "Accurate time!"
# 	else
# 		echo "Inaccurate time"
# 	fi
# 	if [[ "$1" == *3N ]]; then
# 		echo "3N detected"
# 		USP_LOAD_START_MS="${USP_LOAD_START_MS//3N/000}"
# 	fi
# }

# Print elapsed time
# This function expects USP_LOAD_START_MS for total time
# It also stores the time of *last* execution in USP_LOAD_LAST_MS
# Usage: _usp_log_elapsed_load_time SECTION_NAME
_usp_log_elapsed_load_time() {
	if [[ ! -v USP_LOAD_START_MS ]]; then
		return
	elif [[ "$USP_LOAD_START_MS" == *3N ]]; then
		unset USP_LOAD_START_MS
		_usp_log info "$(_usp_color info)NOTE: $(_usp_color)Timing unavailable; install $(_usp_color strong)gdate$(_usp_color) (Homebrew coreutils)"
		return
	fi

	local millis step_elapsed total_elapsed log_str step_name
	millis=$(_usp_get_millis)
	log_str="$(_usp_color info)Timing: $(_usp_color)"
	step_name=${1:="current"}

	if [[ -v USP_LOAD_START_MS ]]; then
		total_elapsed=$(( millis - USP_LOAD_START_MS ))
		log_str+="${total_elapsed}ms elapsed "
	fi

	if [[ -v USP_LOAD_LAST_MS ]]; then
		step_elapsed=$(( millis - USP_LOAD_LAST_MS ))
		log_str+="(${step_elapsed}ms for ${step_name} step)"
	fi

	if [[ -n log_str ]]; then
		_usp_log info "${log_str}"
	fi
	USP_LOAD_LAST_MS=${millis}
}



# Show USP Environment Details
# usp_log_debug "Environment Details"
# usp_log_debug "==================x"
USP_LOG_PREFIX="" _usp_log print "$(_usp_color head)Welcome to USP $(cat ${USP_ROOT}/VERSION)"
_usp_log warn "$(_usp_color)Debug Level: $(_usp_color)${USP_DEBUG}"
_usp_log info "$(_usp_color strong)- PROFILE_ROOT:  $(_usp_color)$(_usp_strip_homedir ${PROFILE_ROOT})"
_usp_log info "$(_usp_color strong)- USP_ROOT:      $(_usp_color)$(_usp_strip_homedir ${USP_ROOT})"
_usp_log info "$(_usp_color strong)- DOTFILES_ROOT: $(_usp_color)$(_usp_strip_homedir ${DOTFILES_ROOT})"
_usp_log info "$(_usp_color strong)- USP_P10K_ROOT: $(_usp_color)$(_usp_strip_homedir ${USP_P10K_ROOT})"

