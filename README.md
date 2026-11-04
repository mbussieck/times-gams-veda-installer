# VedaPy

VedaPy builds the Windows installer for **TIMES_GAMS_Veda** (`TIMES_GAMS_Veda-setup.exe`), which bundles:

- a standalone **Python** (downloaded with [uv](https://docs.astral.sh/uv/)),
- **[GAMSPy](https://github.com/GAMS-dev/gamspy)** with all solvers, installed into that Python. Its `gamspy_base` package provides the GAMS system.
- **[Veda 2.0](https://github.com/kanors-emr/Veda2.0-Installation)**, the localhost edition.

The installer is built by a GitHub Actions workflow and written with [Inno Setup](https://jrsoftware.org/isinfo.php).

## Repository layout

| Path | Purpose |
|---|---|
| `versions.txt` | Versions of uv, Python, GAMSPy and Veda to build with |
| `.github/workflows/build-installer.yml` | Workflow that builds the installer |
| `installer/TIMES_GAMS_Veda.iss` | Inno Setup script |
| `installer/assets/` | Installer icon and wizard images |

## Choosing versions

`versions.txt` contains one `name = version` line per component. Lines starting with `#` are comments. Each version is an exact version or `latest`:

| Name | Allowed values | Examples |
|---|---|---|
| `uv` | An exact release from [uv](https://github.com/astral-sh/uv/releases), or `latest` | `0.9.5`, `latest` |
| `python` | A Python version as understood by uv, or `latest`. A minor version picks its newest patch release. | `3.14`, `3.14.2`, `latest` |
| `gamspy` | An exact version from [PyPI](https://pypi.org/project/gamspy/), or `latest` | `1.18.0`, `latest` |
| `veda` | An exact release from [Veda2.0-Installation](https://github.com/kanors-emr/Veda2.0-Installation/releases) without the leading `v`, or `latest` | `5.0.0.0`, `latest` |

uv is only used to build the installer and is not bundled.

With `latest`, every build picks up the newest release at that moment. Two builds can therefore differ even without a change in this repository. Use exact versions for reproducible builds.

## Building the installer

The workflow only runs when started manually:

1. In the repository on GitHub, open the **Actions** tab.
2. Select **Build Installer** and click **Run workflow**.
3. Under **Use workflow from**, choose the branch to build, then click **Run workflow**.
4. When the run has finished, download **TIMES_GAMS_Veda-setup** from the **Artifacts** section of the run's summary page.

Artifacts are deleted after one day.

The workflow runs on GitHub's hosted `windows-latest` runner and performs these steps:

1. Reads `versions.txt`, sets up uv, installs the Python version with uv and copies it to `build\python`.
2. Installs GAMSPy into that Python and runs `gamspy install solver --install-all-solvers`.
3. Downloads `Veda2.0_localhost_<version>.zip` and extracts it to `build\Veda`. It reads the TIMES version from `initsys.mod` in the `GAMS_SrcTIMES.<version>` folder of the zip.
4. Compiles `installer\TIMES_GAMS_Veda.iss` with the preinstalled Inno Setup. It passes the TIMES version as `/DMyAppVersion=<version>` and the resolved Veda version as `/DVedaVersion=<version>`.
5. Uploads `build\installer\TIMES_GAMS_Veda-setup.exe` as an artifact.

### Building locally

You need Inno Setup 6 and a `build` folder at the repository root, laid out as the workflow creates it:

```
build\python\   standalone Python with GAMSPy and solvers installed
build\Veda\     extracted Veda zip
```

Then compile, passing the TIMES version of `build\Veda\GAMS_SrcTIMES.<version>` and the Veda version of `build\Veda`:

```
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DMyAppVersion=4.9.7 /DVedaVersion=5.0.0.0 installer\TIMES_GAMS_Veda.iss
```

The script refuses to compile without these two values.

## What the installer does

The installer's version is the TIMES version that comes with Veda, for example `4.9.7`. The installer installs for the current user and does not require administrator rights. The default target folder is `C:\TIMES_GAMS_Veda`. If TIMES_GAMS_Veda is already installed, any version installs into that folder without asking, so only one version can be installed at a time.

Installed layout:

```
<install folder>\
├── python\     bundled Python. GAMS is in python\Lib\site-packages\gamspy_base
└── Veda\       contents of the Veda zip
```

During installation it:

- Asks for a GAMS access code and retrieves a license with `gamsgetkey`. The license is written to `gamspy_base\gamslice.txt` and replaces the demo license that ships with GAMSPy.
- Sets the user environment variable `TIMES_GAMS_VEDA_GAMSDIR` to the `gamspy_base` folder. It also adds `%TIMES_GAMS_VEDA_GAMSDIR%` to the front of the user `PATH`. Windows appends the user `PATH` to the system `PATH`, so a GAMS on the system `PATH` takes precedence. VedaPy uses its own variable so that the `GAMSDIR` of a regular GAMS installation stays untouched.
- Creates a **Veda2.0** shortcut on the desktop of the current user and offers to launch Veda when setup finishes.

The uninstaller removes the installed files, the desktop shortcut, `TIMES_GAMS_VEDA_GAMSDIR` and its `PATH` entry.
