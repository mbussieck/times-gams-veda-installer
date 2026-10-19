# VedaPy

VedaPy builds a Windows installer (`VedaPy-setup.exe`) that bundles:

- a standalone **Python** (downloaded with [uv](https://docs.astral.sh/uv/)),
- **[GAMSPy](https://github.com/GAMS-dev/gamspy)** with all solvers, installed into that Python. Its `gamspy_base` package provides the GAMS system.
- **[Veda 2.0](https://github.com/kanors-emr/Veda2.0-Installation)**, the localhost edition.

The installer is built by a GitHub Actions workflow and written with [Inno Setup](https://jrsoftware.org/isinfo.php).

## Repository layout

| Path | Purpose |
|---|---|
| `.python-version` | Python version to bundle |
| `.gamspy-version` | GAMSPy version to bundle |
| `.veda-version` | Veda version to bundle |
| `.github/workflows/build-installer.yml` | Workflow that builds the installer |
| `installer/vedapy.iss` | Inno Setup script |
| `installer/assets/` | Installer icon and wizard images |

## Choosing versions

Each version file contains a single line:

| File | Allowed values | Examples |
|---|---|---|
| `.python-version` | A Python version as understood by uv. A minor version picks its newest patch release. | `3.14`, `3.14.2` |
| `.gamspy-version` | An exact version from [PyPI](https://pypi.org/project/gamspy/), or `latest` | `1.18.0`, `latest` |
| `.veda-version` | An exact release from [Veda2.0-Installation](https://github.com/kanors-emr/Veda2.0-Installation/releases) without the leading `v`, or `latest` | `5.0.0.0`, `latest` |

With `latest`, every build picks up the newest release at that moment. Two builds can therefore differ even without a change in this repository. Use exact versions for reproducible builds.

## Building the installer

The workflow only runs when started manually:

1. In the repository on GitHub, open the **Actions** tab.
2. Select **Build Installer** and click **Run workflow**.
3. Under **Use workflow from**, choose the branch to build, then click **Run workflow**.
4. When the run has finished, download **VedaPy-setup** from the **Artifacts** section of the run's summary page.

Artifacts are deleted after one day.

The workflow runs on GitHub's hosted `windows-latest` runner and performs these steps:

1. Installs the Python version from `.python-version` with uv and copies it to `build\python`.
2. Installs GAMSPy into that Python and runs `gamspy install solver --install-all-solvers`.
3. Downloads `Veda2.0_localhost_<version>.zip` and extracts it to `build\Veda`.
4. Compiles `installer\vedapy.iss` with the preinstalled Inno Setup. It passes the GAMS version of `gamspy_base` as `/DMyAppVersion=<version>` and the resolved Veda version as `/DVedaVersion=<version>`.
5. Uploads `build\installer\VedaPy-setup.exe` as an artifact.

### Building locally

You need Inno Setup 6 and a `build` folder at the repository root, laid out as the workflow creates it:

```
build\python\   standalone Python with GAMSPy and solvers installed
build\Veda\     extracted Veda zip
```

Then compile, passing the GAMS version of `gamspy_base` in `build\python` and the Veda version of `build\Veda`:

```
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DMyAppVersion=54.6.0 /DVedaVersion=5.0.0.0 installer\vedapy.iss
```

The script refuses to compile without these two values.

## What the installer does

The installer's version is the GAMS version that comes with `gamspy_base`, for example `54.6.0`. The installer requires administrator rights. The default target folder is `C:\GAMS_TIMES_Veda\<GAMS major version>`, for example `C:\GAMS_TIMES_Veda\54`.

Installed layout:

```
<install folder>\
├── python\     bundled Python. GAMS is in python\Lib\site-packages\gamspy_base
└── Veda\       contents of the Veda zip
```

During installation it:

- Asks for a GAMS access code and retrieves a license with `gamsgetkey`. The license is written to `gamspy_base\gamslice.txt` and replaces the demo license that ships with GAMSPy.
- Sets the system environment variable `VEDAPY_GAMSDIR` to the `gamspy_base` folder. It also adds `%VEDAPY_GAMSDIR%` to the front of the system `PATH`. VedaPy uses its own variable so that the `GAMSDIR` of a regular GAMS installation stays untouched.
- Creates a **Veda2.0** desktop shortcut and offers to launch Veda when setup finishes.

The uninstaller removes the installed files and the desktop shortcut. It currently leaves `VEDAPY_GAMSDIR` and the `PATH` entry in place.
