# nmux installer

The wrapper an operator runs:

```bash
curl -sSL https://raw.githubusercontent.com/neuralmux/installer/main/install.sh | bash
```

It detects the architecture, downloads the installer binary and its published
checksum from the nmux release, verifies them, and runs the installer.

## These files

`install.sh` is the canonical source. The public `neuralmux/installer`
repository holds a copy of it: that repository exists so the `curl` URL above is
short and stable.

**The copy is not synchronised automatically.** A change here must be copied to
`install.sh` in that repository, or the URL keeps serving the old wrapper —
which is how the previous installer came to ship a binary that leaked the
credential into a world-readable file.

## What the installer does

The binary is `nmux-installer`, built from
[`src/bin/nmux-installer.rs`](../src/bin/nmux-installer.rs) in the nmux
repository. It:

1. checks the credential against the channel, and stops if the channel refuses it;
2. installs the repository's signing key, so apt verifies what it downloads;
3. writes the apt source with `signed-by=`, and the credential to
   `/etc/apt/auth.conf.d/` at mode `0600`;
4. rewrites any apt source that still carries a credential in its URL — the
   shape the previous installer wrote, where every user on the machine could
   read it;
5. runs `apt-get update` and `apt-get install -y nmux`.

Run it with `--dry-run` to see all of that without changing anything, and with
`--root <dir>` to stage the configuration somewhere other than `/`.

## Why a binary rather than a shell script

The installer edits files owned by root in `/etc/apt`, verifies a credential
against a service, and reports what it did. That is a program with behaviour
worth testing — it has unit tests over the plan it builds, and the release
workflow runs it against a staging root before publishing it.
