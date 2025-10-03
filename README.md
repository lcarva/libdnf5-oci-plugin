# LIBDNF5 OCI Plugin

This, experimental!, project enables consuming YUM repositories stored in an OCI registry. It
currently serves as a proof of concept for the [native OCI storage for
DNF](https://discussion.fedoraproject.org/t/native-oci-storage-for-dnf/163534) proposal.

As experiments go, the code in this git repository is written in bash simply because it is simple
to get started. If/when it is decided to move towards production-grade, it must obviously be
re-written in a more suitable technology.

In reality, the content of this git repository don't necessarily implement a plugin. Instead, it
provides a set of scripts that are used in conjunction with the [Actions LIBDNF5
Plugin](https://dnf5.readthedocs.io/en/latest/libdnf5_plugins/actions.8.html).

## How does it work?

The plugin ties into two hooks of the [DNF5
Workflow](https://github.com/rpm-software-management/dnf5/blob/main/doc/dnf5_workflow.rst) to
preempt OCI requests, making content available locally instead. The
[oci.actions](./oci.actions) file defines these connections.

The first hook is the `repos_configured`. The plugin iterates through all the enabled YUM
repositories, finds the ones where `baseurl` use the `oci://` protocol, and fetches the `repodata`
for that image reference. The `repodata` is stored in the DNF cache. Additionally, metadata is also
stored in the cache to avoid unnecessary requests to the OCI registry and to make certain
information available for the next hook. The plugin modifies the YUM repository configuration (the
one in memory, not on disk), to replace the value of `baseurl` with a `file://` URL pointing to the
DNF cache for that particular YUM repository.

Next, the `goal_resolved` hook is used to download each of the RPMs marked for installation from
OCI to the DNF cache directory.

From DNF's perspective, it is installing RPMs from a local YUM repository.

## Installing it

If you want to try this out (have I mentioned this is experimental?!?):

1. Install the actions plugin: `sudo dnf install libdnf5-plugin-actions`.
1. Install `oras`: `sudo dnf install golang-oras`.
1. Install `yq`: `sudo dnf install yq`.
1. Add `oci_repos_configured.sh` and `oci_goal_resolved.sh` somewhere in the `root` user's `PATH`.
1. Link the actions file:
   ```bash
   sudo ln -s `pwd`/oci.actions /etc/dnf/libdnf5-plugins/actions.d/
   ```

That should be sufficient.

If you have gotten this far, you are likely interested in actually using the plugin. You can place
the following YUM repo file under `/etc/yum.repos.d/`:

```ini
[oci-repo-test]
name=oci-repo-test
baseurl=oci://quay.io/lucarval/yum-repo:latest
enabled=1
gpgcheck=1
```

The repository contains `cowsay` and `lolcat`.

