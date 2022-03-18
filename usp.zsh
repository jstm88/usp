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



# Store timing zero reference
# Note: on MacOS, `gdate` must be installed via the Homebrew `coreutils`package.
# If the correct package is installed, then the variable will hold milliseconds.
# If not, then it will be seconds with "3N" appended, which will need to be
# stripped. This will be handled by the USP timing functions.
# Also note: this function is copied from core.zsh to allow timing to begin at
# initial load. I'd like to do this some other way in the future.
if hash gdate 2>/dev/null; then
	USP_LOAD_START_MS=$(gdate +%s%3N)
else
	USP_LOAD_START_MS=$(date +%s%3N)
fi



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
USP_SELF=${${(%):-%x}:A}
USP_ROOT=${USP_SELF:h}
USP_LIB_ROOT="${USP_ROOT}/lib"

# Profile and Dotfiles
PROFILE_ROOT=${PROFILE_ROOT:=${USP_ROOT:h}}
DOTFILES_ROOT=${DOTFILES_ROOT:="${PROFILE_ROOT}/dotfiles"}

# powerlevel10k
USP_P10K_ENABLE=${USP_P10K_ENABLE:=1}
USP_P10K_ROOT=${USP_P10K_ROOT:="${PROFILE_ROOT}/external/powerlevel10k"}
USP_P10K_CONF=${USP_P10K_CONF:="${USP_ROOT}/lib/p10k.zsh"}

# Path and Other Configuration Items
typeset -U path
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



# Load core USP components
if [[ -f "${USP_LIB_ROOT}/core.zsh" ]]; then
	source "${USP_LIB_ROOT}/core.zsh"
else
	echo "USP cannot find core functions!"
	echo "Check that USP is installed correctly."
	return 1
fi

# Load shims for deprecated functions
_usp_source "${USP_LIB_ROOT}/deprecated.zsh"



# Add to path
_usp_path() {
	if [[ $# -eq 0 ]]; then
		print -R ${(j|:|)path}
	else
		local arg="$1"
		shift
		case $arg in
			append)  _usp_path_append  "$@" ;;
			prepend) _usp_path_prepend "$@" ;;
			*) _usp_log warn "$(_usp_color warn)Warning: $(_usp_color)usp-path invalid mode" ;;
		esac
	fi
}

# Manage plugins
# _usp_plugin path append|prepend PATH
# _usp_plugin load NAME
# NOTE: There is a limitation with ZSH plugins
# Until a better way is found, the path is generated explicitly
# and not using `find` as with the list option. This is because
# we are loading code and not just scanning directories. As such
# the ZSH plugins must be named correctly. Otherwise, this can
# be overcome by just using `usp-source` to load them directly.
_usp_plugin() {
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
					usp source "$plug_path"
					return 0
				elif [[ -f "$plug_path_omz" ]]; then
					usp source "$plug_path_omz"
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
# Example: $(_usp_is_platform linux darwin) passes on Linux and Mac
# You can then do like `_usp_is_platform linux && linux-specific-cmd`
_usp_is_platform() {
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

_USP_USAGESTR=$(cat <<-END
Usage:
    usp COMMAND    Run the specified command
Commands:
    reload
    update
    debug
    path
    plugin
    source
    log
    clobbertest
    is-platform
    help
Flags:
    (none)
END
)

usp() {
	local ARG=$1
	[[ $# -ge 1 ]] && shift
	case "$ARG" in
		reload)
			_usp_reload "$@"
			;;
		update)
			_usp_update "$@"
			;;
		debug)
			_usp_cmd_debug "$@"
			;;
		path)
			_usp_path "$@"
			;;
		plugin)
			_usp_plugin "$@"
			;;
		source)
			_usp_source "$@"
			;;
		log)
			_usp_log "$@"
			;;
		clobbertest)
			_usp_clobbercheck "$@"
			;;
		is-platform)
			_usp_is_platform "$@"
			;;
		*)
			echo "${_USP_USAGESTR}"
			;;
	esac
}



_usp_log_elapsed_load_time "Initial"



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
	usp source -q "${DOTFILES_ROOT}/zshrc.zsh"
	usp source -q "${DOTFILES_ROOT}/byplatform/`_usp_get_uname`.zsh"
	usp source -q "${DOTFILES_ROOT}/byhost/`_usp_get_hostname`.zsh"
}

_usp_load_local_dotfiles() {
	if [[ -v DOTFILES_LOCAL ]]; then
		local _local_dotfile
		for _local_dotfile in $_dotfiles_local; do
			if [[ -f "$_local_dotfile" ]]; then
				# usp_log_debug "Loading private RC file:"
				usp source "$_local_dotfile"
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

_usp_log_elapsed_load_time "Remainder"

if [[ -v USP_DEBUG_PREVIOUS ]]; then
	USP_DEBUG="${USP_DEBUG_PREVIOUS}"
	unset USP_DEBUG_PREVIOUS
fi
