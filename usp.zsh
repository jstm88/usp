# USP: A top-level ZSH shell autoloader
#
# To use USP, you should do the following:
# 1. Set any USP environment vars you wish to configure
# 2. Source the main USP file
#
# Configurable Environment Variables
# Set these in your ~/.zshrc file before sourcing USP
# ---------------------------------------------------
# Main Flags
# - USP_DEBUG          Logging level {off|print|err|warn|info}
# - PROFILE_ROOT       The root profile directory
# - DOTFILES_ROOT      The root location to start looking for dotfiles
# - DOTFILES_LOCAL     Array of dotfiles local only to this machine
# --------------------------------------------------------------------
# Powerlevel10k
# - USP_P10K_ENABLE    1 to enable, 0 to disable
# - USP_P10K_ROOT      Root of powerlevel10k repo
# - USP_P10K_CONF      Path to the configuration file
# ---------------------------------------------------
# Miscellaneous Customizations
# - USP_LOG_PREFIX     The string to append before USP log lines
# --------------------------------------------------------------
# Development and Advanced Debugging
# - USP_DRY_RUN        Do not load anything, and just print log information
#                      (not yet implemented)



# On first launch, record any *existing* variables, functions, and aliases
# We will use this later for help and documentation purposes
# [[ -v usp_pre_p10k_parameters ]] || usp_pre_p10k_parameters=(${(k)parameters})
# [[ -v usp_pre_p10k_functions  ]] || usp_pre_p10k_functions=(${(k)functions})
# [[ -v usp_pre_p10k_aliases    ]] || usp_pre_p10k_aliases=(${(k)aliases})



# Set up Default Environment and Settings
# =============================================================================

# DEBUG LEVELS
USP_DEBUG=${${USP_DEBUG:="err"}:l}
if [[ -v USP_DEBUG_OVERRIDE ]]; then
	USP_DEBUG_PREVIOUS="${USP_DEBUG}"
	USP_DEBUG="${USP_DEBUG_OVERRIDE}"
	unset USP_DEBUG_OVERRIDE
fi
typeset -A _usp_debug_map=([off]=0 [print]=1 [err]=2 [warn]=3 [info]=4)
(( ! ${+_usp_debug_map[${USP_DEBUG}]} )) && USP_DEBUG="err"

# Main Paths and Root Directory
USP_SELF=${${(%):-%x}:A} # This file
USP_ROOT=${USP_SELF:h}   # Parent directory

# Profile and Dotfiles
PROFILE_ROOT=${PROFILE_ROOT:=${USP_ROOT:h}} # Parent directory of usp
DOTFILES_ROOT=${DOTFILES_ROOT:="${PROFILE_ROOT}/dotfiles"} # Default

# powerlevel10k
USP_P10K_ENABLE=${USP_P10K_ENABLE:=1}
USP_P10K_ROOT=${USP_P10K_ROOT:="${PROFILE_ROOT}/external/powerlevel10k"}
USP_P10K_CONF=${USP_P10K_CONF:="${USP_ROOT}/lib/p10k.zsh"}

# Path and Other Configuration Items
typeset -U path # Make path elements unique
USP_LOG_PREFIX=${USP_LOG_PREFIX:="| "}
typeset -T DOTFILES_LOCAL _dotfiles_local :
typeset -Ua _dotfiles_local

# Plugin Directories
typeset -Ua _usp_plugin_path



# powerlevel10k Instant Prompt
# =============================================================================

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ ${USP_P10K_ENABLE} -eq 1 ]]; then
	if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
		source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
	fi
fi



# USP Internal Helper Functions and Extras
# =============================================================================

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
	FILE="$1"
	if [[ -f "$FILE" ]]; then
		_usp_log info "$(_usp_color ok)Loading $(_usp_color)$(_usp_clean_path $FILE)"
		source $FILE
	else
		_usp_log warn "$(_usp_color warn)No file $(_usp_color)$(_usp_clean_path $FILE)"
	fi
}

# Append an element to the $PATH variable
# In ZSH, $PATH is tied to the $path array
# To add to end, `path+=(~/foo)`
# To add to beginning, `path=(~/foo "$path[@]")` or `path[1,0]=~/foo`
# As long as `typeset -U path` is used, items will be unique
_usp_path_prepend() {
	if [[ -d "$1" ]]; then
		path[1,0]="$1"
		_usp_log info "$(_usp_color info)Prepended to PATH: $(_usp_color)$(_usp_clean_path $1)"
	else
		_usp_log warn "$(_usp_color warn)Path does not exist: $(_usp_color)$(_usp_clean_path $1)"
	fi
}

_usp_path_append() {
	if [[ -d "$1" ]]; then
		path+="$1"
		_usp_log info "$(_usp_color info)Appended to PATH: $(_usp_color)$(_usp_clean_path $1)"
	else
		_usp_log warn "$(_usp_color warn)Path does not exist: $(_usp_color)$(_usp_clean_path $1)"
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



# Show USP Environment Details
# usp_log_debug "Environment Details"
# usp_log_debug "==================x"
USP_LOG_PREFIX="" _usp_log print "$(_usp_color head)Welcome to USP $(cat ${USP_ROOT}/VERSION)"
_usp_log warn "$(_usp_color)Debug Level: $(_usp_color)${USP_DEBUG}"
_usp_log info "$(_usp_color strong)- PROFILE_ROOT:  $(_usp_color)$(_usp_strip_homedir ${PROFILE_ROOT})"
_usp_log info "$(_usp_color strong)- USP_ROOT:      $(_usp_color)$(_usp_strip_homedir ${USP_ROOT})"
_usp_log info "$(_usp_color strong)- DOTFILES_ROOT: $(_usp_color)$(_usp_strip_homedir ${DOTFILES_ROOT})"
_usp_log info "$(_usp_color strong)- USP_P10K_ROOT: $(_usp_color)$(_usp_strip_homedir ${USP_P10K_ROOT})"



# DEPRECATION SHIMS
# =============================================================================

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



# SHELL FILE API
# =============================================================================

# These functions are designed for use within your configuration files
# and for plugins designed for USP.

# Source a file
usp-source() {
	_usp_source "$@"
}

# Log errors
usp-log() {
	_usp_log "$@"
}

# Add to path
usp-path() {
	if [[ $# -eq 1 ]]; then
		print -R ${(j|:|)path}
	elif [[ $# -eq 1 ]]; then
		_usp_path_append "$@"
	elif [[ $# -eq 2 ]]; then
		local arg="$1"
		shift
		case $arg in
			append)  _usp_path_append  "$@" ;;
			prepend) _usp_path_prepend "$@" ;;
			*) _usp_log warn "$(_usp_color warn)Warning: $(_usp_color)usp-path invalid mode" ;;
		esac
	else
		_usp_log warn "$(_usp_color warn)No path provided to usp-path function"
	fi
}

# Check for existing aliases, functions, or variables
usp-clobber-check() {
	_usp_clobbercheck "$@"
}

# Manage plugins
# usp-plugin path append|prepend PATH
# usp-plugin load NAME
# NOTE: There is a limitation with ZSH plugins
# Until a better way is found, the path is generated explicitly
# and not using `find` as with the list option. This is because
# we are loading code and not just scanning directories. As such
# the ZSH plugins must be named correctly. Otherwise, this can
# be overcome by just using `usp-source` to load them directly.
usp-plugin() {
	if [[ $# -gt 0 ]]; then
		local cmd="${1:l}"; shift
		if [[ "$cmd" == "path" && $# -eq 0 ]]; then
			print -R ${(j|:|)_usp_plugin_path}
			return 0
		elif [[ "$cmd" == "path" && $# -eq 2 ]]; then
			local mode="${1:l}"; shift
			local path="$1"; shift
			case $mode in
				append)  _usp_plugin_path_append  "$path"; return 0 ;;
				prepend) _usp_plugin_path_prepend "$path"; return 0 ;;
				$)       ;;
			esac
		elif [[ "$cmd" == "load" && $# -eq 1 ]]; then
			local name="$1"; shift
			local plugin_prefix
			for plugin_prefix in $_usp_plugin_path; do
				local plug_path="${plugin_prefix}/${name}.zsh"
				local plug_path_omz="${plugin_prefix}/${name}/${name}.plugin.zsh"
				if [[ -f "$plug_path" ]]; then
					usp-source "$plug_path"
					return 0
				elif [[ -f "$plug_path_omz" ]]; then
					usp-source "$plug_path_omz"
					return 0
				fi
			done
			_usp_log warn "$(_usp_color warn)Could not load plugin: $(_usp_color)${name}"
			return 1
		elif [[ "$cmd" == "list" ]]; then
			local plugin_prefix
			local plugin
			for plugin_prefix in $_usp_plugin_path; do
				echo "$(_usp_color strong)> $(_usp_clean_path ${plugin_prefix})$(_usp_color)"
				for plugin in $(find "${plugin_prefix}" -name "*.zsh"); do
					echo "  - ${plugin:t:r}"
				done
			done
			return 0
		fi
	fi
	_usp_log warn "$(_usp_color warn)usp-plugin command failed"
	return 1
}

# Succeed (return 0) if the platform matches one of the arguments
# Example: $(usp-is-platform linux darwin) passes on Linux and Mac
# You can then do like `usp-is-platform linux && linux-specific-cmd`
usp-is-platform() {
	local my_plat=$(_usp_get_uname)
	local test_plat
	for test_plat in $@; do
		if [[ ${test_plat:l} == ${my_plat} ]]; then
			return 0
		fi
	done
	return 1
}



# USP CONTROL COMMAND
# =============================================================================

# The main USP function provides documentation
# and shell reload functionality
# ---------------------------------------------
# usp help
# usp reload [-d|--debug]
# usp debug [none|err|warn|info|default]
# usp path [append|prepend] PATH
# usp plugin path append|prepend PATH
# usp plugin load NAME
# usp info (to be implemented)
usp() {
	local ARG=$1
	[[ $# -ge 1 ]] && shift
	case "$ARG" in
		help)
			echo "No help available yet"
			;;
		reload)
			_usp_reload "$@"
			;;
		debug)
			_usp_cmd_debug "$@"
			;;
		path)
			usp-path "$@"
			;;
		plugin)
			usp-plugin "$@"
			;;
		*)
			echo "Invalid command"
			;;
	esac
}



# MAIN LOADER FUNCTIONS
# =============================================================================

_usp_load_powerlevel10k() {
	[[ ${USP_P10K_ENABLE} -ne 1 ]] && return 1

	if [[ -f "${USP_P10K_ROOT}/powerlevel10k.zsh-theme" ]]; then
		source "${USP_P10K_ROOT}/powerlevel10k.zsh-theme"
	else
		echo "Can't find powerlevel10k.zsh-theme at ${USP_P10K_ROOT}..."
	fi
	# To customize prompt, run `p10k configure` or edit p10k.zsh directly
	# To silence debug warnings with instant prompt, set this in the p10k file:
	# typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
	if [[ -f "${USP_P10K_CONF}" ]]; then
		source "${USP_P10K_CONF}"
	else
		_usp_log err "$(_usp_color err)ERROR: $(_usp_color)No p10k file found!"
	fi
}

_usp_load_primary_dotfiles() {
	usp-source "${DOTFILES_ROOT}/global/zshenv.zsh"
	usp-source "${DOTFILES_ROOT}/global/zshrc.zsh"
	usp-source "${DOTFILES_ROOT}/byplatform/`_usp_get_uname`/zshenv.zsh"
	usp-source "${DOTFILES_ROOT}/byplatform/`_usp_get_uname`/zshrc.zsh"
	usp-source "${DOTFILES_ROOT}/byhost/`_usp_get_hostname`/zshenv.zsh"
	usp-source "${DOTFILES_ROOT}/byhost/`_usp_get_hostname`/zshrc.zsh"
}

_usp_load_local_dotfiles() {
	if [[ -v DOTFILES_LOCAL ]]; then
		local _local_dotfile
		for _local_dotfile in $_dotfiles_local; do
			if [[ -f "$_local_dotfile" ]]; then
				# usp_log_debug "Loading private RC file:"
				usp_rcload "$_local_dotfile"
			else
				_usp_log "$(_usp_color err)Private RC file specified but not found: $(_usp_color)$_local_dotfile"
			fi
		done
	fi
}



# MAIN
# =============================================================================

() {
	_usp_load_powerlevel10k
	_usp_load_primary_dotfiles
	_usp_load_local_dotfiles
	# Optionally perform function cleanup
}



# EXCESS STUFF
# =============================================================================

# Record parameters after loading p10k
# [[ -v usp_pre_env_parameters ]] || usp_pre_env_parameters=(${(k)parameters})
# [[ -v usp_pre_env_functions  ]] || usp_pre_env_functions=(${(k)functions})
# [[ -v usp_pre_env_aliases    ]] || usp_pre_env_aliases=(${(k)aliases})

# usp_print_alias_diffs() {
# 	for item in ${(k)aliases}; do
# 		if (( ! $usp_pre_env_aliases[(Ie)$item] )); then
# 			echo "$item"
# 		fi
# 	done
# }

# usp_print_function_diffs() {
# 	for item in ${(k)functions}; do
# 		if (( ! $usp_pre_env_functions[(Ie)$item] )); then
# 			echo "$item"
# 		fi
# 	done
# }

# usp_print_parameter_diffs() {
# 	for item in ${(k)parameters}; do
# 		if (( ! $usp_pre_env_parameters[(Ie)$item] )); then
# 			echo "$item"
# 		fi
# 	done
# }

# [ ] TODO: Load built-in plugins here
#           There should be a way for the user to override
#           specific plugins. For this reason, plugins from
#           USP will be loaded last. USP plugins will also
#           check to ensure they will not override any
#           existing commands or aliases, and will throw a
#           warning and fail to load if this is the case.
# PSEUDOCODE:
# for each plugin:
#     PNAME := name of plugin capitalized
#     look for variable named "USP_PLUGIN_ENABLE_$PNAME"
#     set to default if unset (see notes below)
#     if true, then load the plugin
#     if false, log that it was skipped
# OPTIONAL: maybe we should handle user plugins here as well
# UTILITY: Add a function that lists plugins, and then prints
#          a configuration block that can be pasted into your zshrc
# ALSO: Consider what happens when new plugins are added. Maybe
#       there should be a way to change the defaults? For example:
#       USP_PLUGINS_SKIP_BY_DEFAULT=1 will only load plugins that
#       have explicitly been enabled

# alias usp-update-profile="\
# 	USP_PREUPDATE_PWD=`pwd`;\
# 	cd \"${PROFILE_ROOT}\";\
# 	git pull;\
# 	cd \"$USP_PREUPDATE_PWD\";\
# 	unset USP_PREUPDATE_PWD;\
# 	usp-reload\
# "

if [[ -v USP_DEBUG_PREVIOUS ]]; then
	USP_DEBUG="${USP_DEBUG_PREVIOUS}"
	unset USP_DEBUG_PREVIOUS
fi
