# Silverblue Tilt

This is a bash script for installing and managing all the dependencies of Tilt + Kind on Podman-based desktops such as Silverblue.

## To install

You can run this script from anywhere. To install it into your `~/.local/bin`:

```
mkdir -p ~/.local/bin
install <(curl -s https://raw.githubusercontent.com/fishpercolator/silverblue-tilt/main/tilt-setup.sh) ~/.local/bin/tilt-setup.sh
```

## Running

At the moment, the script takes no options - just run it:

```
tilt-setup.sh
```

It will:

1. Check you have the latest versions of kubectl, kind, helm and tilt and install them into your `~/.local/bin` if not.
2. Create a Kind control plane container and registry if they don't already exist
3. Start these pods if they have been stopped

## Rails example application

This repo contains a Rails example application that you can use to verify your Tilt setup, and also potentially use as a base for building your own Rails applications using this setup.

### To use

```
git clone https://github.com/fishpercolator/silverblue-tilt.git
cd silverblue-tilt/rails-example
tilt up
```

### How it was configured

The Rails application was initialized using:

```
rails new --javascript=esbuild --css=bulma -d postgresql rails-example
```

This puts some handy JS and CSS pipelines in place that can be used to verify that the `live_update` features of the Tiltfile are working properly.

The environment was then customized for Tilt in [this commit](https://github.com/fishpercolator/silverblue-tilt/commit/5ca0c053519cbbf02af406e96686dfb33d07dc82) - specifically:

1. Removed `bin/dev` and `Procfile.dev`, since Tilt is taking the place of Foreman in our development environment
2. Added a `Containerfile.dev` that is similar to the default `Dockerfile` but runs everything in development mode. Ideally the common parts would be abstracted into their own module.
3. Added a `k8s.yaml` file that contains the Kubernetes configuration of the main app, including secret-sharing and ports.
4. Modified `database.yml` to refer to the Kubernetes resources rather than assuming a database on localhost.
5. Added a `Tiltfile` that configures a PostgreSQL database using Helm, and the app configuration itself, using `live_update` to ensure the appropriate parts are rebuilt when things change.
6. Added a `tilt-run` script that allows you to run commands on the running application using `kubectl exec`.
7. The Tiltfile also contains two buttons that run common `tilt-run` commands - one for running new DB migrations, and one for completely resetting the DB to the seed values.

## Future ideas

* Add options for dry run
* Add support for architectures other than amd64
* Add commands to stop and/or uninstall
