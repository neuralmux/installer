# nmux installer

The entry point an operator runs:

```bash
curl -sSL https://raw.githubusercontent.com/neuralmux/installer/main/install.sh | bash
```

`install.sh` detects the architecture, downloads the installer binary and its
published checksum from the nmux release, verifies that the two agree, and runs
it. The installer configures the apt channel and installs `nmux`.

## This repository is a pointer

It exists so the URL above is short and stable. It holds no source: the
installer binary is built and released by
[`neuralmux/nmux.rs`](https://github.com/neuralmux/nmux.rs), from the same commit
as the package it installs.

- **Canonical `install.sh`** — `installer/install.sh` in that repository. Edit it
  there; this copy follows.
- **Installer source** — `src/bin/nmux-installer.rs` and `src/installer/` there.
- **Downloads** — `releases/latest/download/` in that repository.

The workflow that once built the installer here has been removed. It read the
installer's source from the v1 repository and published it by hand, and the
binary it last published was older than the fix that stopped writing the
credential into a world-readable apt source file.
