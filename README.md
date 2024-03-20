# Silverblue Tilt

This is a bash script for installing and managing all the dependencies of Tilt + Kind on Podman-based desktops such as Silverblue.

# To install

You can run this script from anywhere. To install it into your `~/.local/bin`:

```
install <(curl -s https://raw.githubusercontent.com/fishpercolator/silverblue-tilt/main/tilt-setup.sh) ~/.local/bin/tilt-setup.sh
```

# Running

At the moment, the script takes no options - just run it:

```
tilt-setup.sh
```

It will:

1. Check you have the latest versions of kubectl, kind, helm and tilt and install them into your `~/.local/bin` if not.
2. [TODO] Create a Kind control plane container and registry if they don't already exist
3. [TODO] Start these pods if they have been stopped

# Future ideas

* Add options for dry run
* Add support for architectures other than amd64
* Add commands to stop and/or uninstall
