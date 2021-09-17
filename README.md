# Universal Shell Profile

> **NOTE: The README is currently being updated. This is very much a work in progress!**
>
> Additionally, there is currently no "sample" zshrc file, but I plan to make some of mine public in the future. USP currently tries to do very little by default, with the exception of the included powerlevel10k configuration.

## What is USP?

USP is an attempt to create a user-friendly ZSH based shell configuration framework. It's loosely inspired by the likes of [ohmyzsh](https://github.com/ohmyzsh/ohmyzsh) and [zsh4humans](https://github.com/romkatv/zsh4humans) but attempts to leave as much up to the user as possible, with a focus on structuring dotfiles in a logical way.

It consists of the following elements:

- A base ZSH profile with some helpful functions
- An elegant powerlevel10k implementation for a fancy shell prompt
- A logical dotfile loader and convenience functions to simplify extension

USP operates on the following philosophies:

1. The `~/.zshrc` file should require minimal modification
2. All dotfiles, scripts, support files, etc. should be stored in a Git repository controlled by the user
3. USP should be configured as a submodule within the user's profile repository

## Why ZSH?

I debated for a long time whether or not to switch from Bash to ZSH. Bash is by far the most compatible shell available. ZSH, though, is largely compatible with Bash directives so migrating does not require significant effort, and it offers some distinct advantages.

On MacOS, ZSH is now the default shell, so as long as you haven't changed it you're good to go. On Linux, specifically Ubuntu, ZSH must be isntalled, but switching over is extremely easy.

## Installing USP

USP is meant to be included as part of a profile directory. I *highly* recommend creating one and storing it as a Git repository. This way, all you'll need to do when you set up a new system is clone that repository.

Creating the initial profile can be done with the following script:

`command to be developed soon`

Or you can set it up manually. An example setup can be created as follows:

```bash
cd ~
mkdir -p profile/bin
mkdir -p profile/dotfiles/global
mkdir -p profile/external
cd profile
git init .
touch dotfiles/global/zshrc.zsh
git add dotfiles/global/zshrc.zsh
git submodule add --depth=1 -b master https://github.com/jstm88/usp.git usp
git submodule add --depth=1 -b master https://github.com/romkatv/powerlevel10k.git external/powerlevel10k
git add .gitmodules
git commit -m "Initial Profile"
# Add remote and push to your private repository
```

From that point forward, getting your profile set up on a new computer is trivial:

```bash
cd ~
git clone YOUR_PROFILE_URL profile
cd profile
git submodule init
git submodule update --recursive --remote --init
# TBD: a bootstrap/install script
```

To fix usp not pointing to latest branch:

```bash
git config -f .gitmodules submodule.usp.branch master
git config -f .gitmodules submodule.usp.update rebase
```

I also recommend setting up Git to automatically recurse submodules:

```bash
git config --global submodule.recurse true
```

The complete set of directories that USP expects to find are as follows:

```
~/profile
├── bin            # Executable scripts for shell use
├── dotfiles       # All ZSH customizations
│   └── (*)        # See details in "Dotfiles" section
├── ref            # Reference and personal documentation
├── support        # Utility scripts, linked conf files, etc.
├── usp            # The main USP directory
└── external       # Location for submodules and other downloaded packages
    └── (*)        # Submodules
```

> **NOTE: The following does not yet work. The bootstrap script has not been implemented yet.**
>
> Once USP is in place, you can bootstrap USP. The simplest way is by running `~/profile/usp/bootstrap`. This does the following:
>
> - If `~/.zshrc` contains the USP call, exit; it's already set up
> - If `~/zshrc-previous` exists, exit with an error message
> - Move `~/.zshrc` to `~/zshrc-previous`
> - Create a new `~/.zshrc` file
>

To manually enable USP, just add the following line to your `~/.zshrc` file:

```bash
source ~/profile/usp/usp.zsh
```

Anything that was in the previous `.zshrc` can now be moved into the zshrc.zsh in `~/profile/dotfiles/global/zshrc.zsh`.

On the Mac, you'll need to install [Homebrew](https://brew.sh) and a few dependencies. (These will need to be enumerated, and the bootstrap script will eventually handle it automatically.)

## How It Works

USP follows a logical progression when loading dotfiles. First, source `usp.zsh` in your `~/.zshrc` file. From there, it takes over everything in the following sequence:

1. If present, the `powerlevel10k` instant prompt is loaded.
2. Custom values for environment variables (see "Configuration Variables") are read
3. The `usp-helpers.zsh` file is loaded to provide convenience functions
4. If present, `powerlevel10k` is loaded.
5. Dotfiles are loaded in the following order:
	- dotfiles/global/zshenv.zsh
	- dotfiles/global/zshrc.zsh
	- dotfiles/byplatform/PLATFORM/zshenv.zsh
	- dotfiles/byplatform/PLATFORM/zshrc.zsh
	- dotfiles/byhost/HOSTNAME/zshenv.zsh
	- dotfiles/byhost/HOSTNAME/zshrc.zsh
6. Step 5 is repeated for the (varname_tbd) dotfile directory, if set and present
7. Any files defined in `DOTFILES_LOCAL` are loaded
8. USP helper functions are unloaded

## Configuration Variables

In your `~/.zshrc` you can set a small number of USP configuration variables. These variables are given here, along with their default values and a brief explanation.

| Variable           | Default            | Description      |
|:-------------------|:-------------------|:-----------------|
| Variable           | Def                | Desc             |

## USP Documentation

- [ ] TODO: Add a documentation printer to parse/output Markdown files

## Tree Structure for ~/profile/dotfiles

Required:
- `global`: configurations that apply to ZSH in general
- `byplatform`: platform-specific configurations
- `byhost`: host-specific configurations

Optional:
- `bin`: standalone scripts
- `lib`: library functions for shell scripts
- `plugins`: additional scripts for zsh functions and configs

### Using byplatform and byhost

Valid platforms are the output of `uname -s` lowercased. Currently used:

- "darwin"
- "linux"

The path can be one of the following:

- `PLATFORM/zshenv.zsh`
- `PLATFORM/zshrc.zsh`

They will be sourced in that order.

Hosts behave the same way, but utilize the output of `hostname`

The `zshenv.zsh` files should be used for environment setup where interactive scripts may want to break out the functionality at a later time. Otherwise, use `zshrc.zsh`.

### plugins & lib

For common RC files that are sourced independently and provide related functions, it's best practice to put them into `plugins`.

For files that provide common functions used by other RC files, `lib` can be used. As a rule, these files are meant to be sourced by scripts as needed and should be idempotent.

## Dotfile Considerations

USP, by default, does *not* load `~/.profile`. If you want it to be loaded, you should do it somewhere in your own dotfiles.
