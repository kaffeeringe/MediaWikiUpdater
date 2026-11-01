# MediaWiki Update Script

`update_mediawiki.sh` is a shell script that performs a **side-by-side major update** of a self-hosted [MediaWiki](https://www.mediawiki.org/) installation on a shared webspace (developed and tested on **Strato**). Instead of patching your live wiki in place, it downloads a fresh release, rebuilds your customization on top of it, and runs the database update — the upgrade method recommended by MediaWiki for major version jumps.

> ⚠️ **Before you run it:** Back up your database and your `LocalSettings.php`. The script uses `set -e` and stops on the first error, but a backup is your safety net for anything this script (or an extension) might miss.

---

## What it does

In short, the script:

1. Downloads the new MediaWiki release tarball from `releases.wikimedia.org` and unpacks it into a new folder `mediawiki-<NEW_VER>`.
2. Copies your customized files (logo, favicon, `.htaccess`, verification files, …) from the old installation into the new one.
3. Replaces the fresh `images/` folder with a symlink to your central uploads folder.
4. Clones all third-party extensions you listed — automatically picking the right `REL1_46`-style branch for Gerrit extensions — and installs their Composer dependencies.
5. Copies over `LocalSettings.php` and runs the MediaWiki database update (`maintenance/run.php update`).

Your old installation stays untouched the whole time, so you can test the new version before removing the old folder and switching the document root.

---

## Requirements

- **SSH/shell access** to your webspace (the script is interactive-free and runs from the command line).
- `bash`, `wget`, `tar`, `git` available on the host.
- A working **PHP CLI** binary (on Strato: `/opt/RZphp84/bin/php-cli`).
- `composer.phar` located **one level above** the MediaWiki folders (in your document root, next to the script).
- Your current wiki living in a folder named `mediawiki-<version>` (e.g. `mediawiki-1.45.1`), and your uploaded files in a central `images/` folder **next to** the MediaWiki folders — not inside them.
- The git URLs of all extensions your wiki uses.

---

## Expected directory layout

The script assumes your document root looks like this:

```
/document-root/
├── update_mediawiki.sh        # this script
├── composer.phar              # Composer, one level above the wiki folders
├── images/                    # central uploads folder (shared across updates)
├── mediawiki-1.45.1/          # your current ("old") wiki
│   ├── LocalSettings.php
│   ├── wiki.png
│   ├── favicon.ico
│   ├── .htaccess
│   └── ...
└── mediawiki-1.46.2/          # created by the script
```

**Why the central `images/` folder?** Because uploads live outside the release folder, no files have to be moved between versions. The script just deletes the freshly unpacked (empty) `images/` folder in the new release and creates a symlink to the central one. 

---

## How it works, step by step


| Step      | What happens                                                                                                                                                                                                                                                                                                                                                                                   |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **1/10**  | `wget` downloads `mediawiki-$NEW_VER.tar.gz` from the Wikimedia release server.                                                                                                                                                                                                                                                                                                                |
| **2/10**  | The tarball is unpacked into `mediawiki-$NEW_VER/`, then the archive is deleted.                                                                                                                                                                                                                                                                                                               |
| **3/10**  | The script `cd`s into the **old** folder `mediawiki-$OLD_VER`.                                                                                                                                                                                                                                                                                                                                 |
| **4/10**  | Custom files are copied from the old installation into the new one: `wiki.png`, `favicon.ico`, `.htaccess` and a Google site-verification HTML file (each copy only runs if `wiki.png` exists in the old folder).                                                                                                                                                                              |
| **5/10**  | The script `cd`s into the **new** folder.                                                                                                                                                                                                                                                                                                                                                      |
| **6/10**  | The stock `images/` folder shipped with the release is deleted.                                                                                                                                                                                                                                                                                                                                |
| **7/10**  | Symlinks are created: `images → ../images`                                                                                                                                                                                                                                                                                                                     |
| **8/10**  | All extensions are cloned into `extensions/`. Gerrit extensions are cloned with the branch `REL<MAJOR_VER>` (dots replaced by underscores, e.g. `REL1_46`), so you always get the branch matching your new MediaWiki version. GitHub extensions use their default branch. For every extension that ships a `composer.json`, Composer dependencies are installed (`composer install --no-dev`). |
| **9/10**  | `LocalSettings.php` is copied from the old installation into the new folder.                                                                                                                                                                                                                                                                                                                   |
| **10/10** | The database update runs: `php maintenance/run.php update` (equivalent to the classic `update.php`).                                                                                                                                                                                                                                                                                           |


The script uses `set -e`, so it aborts on the first failing command — you won't end up with a half-updated wiki without noticing.

---

## Usage

1. Adjust the configuration block at the top of the script (see below).
2. Upload the script to your document root (the folder that *contains* `mediawiki-1.xx.x`), next to `composer.phar`.
3. Log in via SSH and run:
  ```bash
   cd /path/to/document-root
   bash update_mediawiki.sh
  ```
4. When the script reports **"Update erfolgreich abgeschlossen!"**, test the new wiki thoroughly (login, edit, upload, special pages, skins, extensions).
5. If everything works, point your domain/document root to `mediawiki-<NEW_VER>` (via symlink or hoster config) and delete the old folder.
6. For the next update, change the versions at the top of the script and start over.

> 💡 **Downtime tip:** Because the old folder keeps running until you switch the document root, downtime is minimal. If you need zero downtime, put a maintenance notice in your `.htaccess` during the database update step.

---

## Adjusting the script to your needs

### 1. Versions (top of the script)

```bash
OLD_VER="1.45.1"   # your current version → folder name mediawiki-1.45.1
NEW_VER="1.46.2"   # the version you want → folder name mediawiki-1.46.2
MAJOR_VER="1.46"    # major.minor, used for the download path and the REL1_46 branch names
```

- `OLD_VER` and `NEW_VER` must match your actual folder names.
- `MAJOR_VER` is derived from `NEW_VER` and drives both the download URL and the Gerrit branch (`REL${MAJOR_VER//./_}` → `REL1_46`). Don't forget to update it together with `NEW_VER`.

### 2. Files copied from the old installation (step 4)

The block in step 4 copies `wiki.png`, `favicon.ico`, `.htaccess` and `googlec9230c811948caa1.html`. Edit this list to match your installation — for example:

```bash
# 4. Eigene Dateien kopieren
cp wiki.png          "../mediawiki-${NEW_VER}/"
cp favicon.ico       "../mediawiki-${NEW_VER}/"
cp .htaccess         "../mediawiki-${NEW_VER}/"
cp robots.txt        "../mediawiki-${NEW_VER}/"   # any other file you customized
```

Note: the copies are guarded by `if [ -f "wiki.png" ]`, so if your wiki doesn't use that exact logo filename, adjust the condition too — otherwise *nothing* gets copied. Custom **skins** are not handled by the script; either clone them the same way as extensions or copy your skin folder over manually.

### 3. Extensions (step 8)

You need the **git URL of every extension** your wiki uses. The script distinguishes two kinds:

- **Gerrit (wikimedia.org) extensions** — cloned with an explicit branch derived from `MAJOR_VER`, so they always match your MediaWiki version:
  ```bash
  git clone -b "REL${MAJOR_VER//./_}" https://gerrit.wikimedia.org/r/mediawiki/extensions/Arrays.git
  ```

  Just add or remove lines to match the `wfLoadExtension(...)` calls in your `LocalSettings.php`.
- **External GitHub extensions** — cloned from their default branch (make sure the repo supports your MediaWiki version):
  ```bash
  git clone https://github.com/ProfessionalWiki/Maps.git
  git clone https://github.com/Wikia/mediawiki-extensions-EmbedVideo.git EmbedVideo   # optional: target folder name
  ```

Everything in `LocalSettings.php` that isn't bundled with MediaWiki core must appear here, otherwise the new wiki will throw errors about missing extensions.

### 4. PHP / Composer (step 8, and step 10)

The script was written for **Strato**, where Composer must be invoked through the hoster's PHP binary:

```bash
/opt/RZphp84/bin/php-cli ../../composer.phar install -d "${ext_dir%/}" --no-dev ...
```

- **On Strato:** update the PHP binary path whenever you switch the PHP version (`RZphp84` = PHP 8.4). `composer.phar` is expected one level above the wiki folders.
- **On other webspaces:** replace the call with whatever works on your host, e.g.:
  ```bash
  php composer.phar install -d "${ext_dir%/}" --no-dev --optimize-autoloader --ignore-platform-reqs
  # or, if Composer is installed globally:
  composer install -d "${ext_dir%/}" --no-dev --optimize-autoloader
  ```
- The `composer config policy.advisories.block false` line merely suppresses aborts on security-advisory warnings in Composer 2.7+; you can drop it if you'd rather see those warnings.

### 5. Symlinks (step 7)

```bash
ln -s ../images images     # central uploads folder
```

If your uploads live inside the wiki folder instead, delete step 6 and 7 and copy your `images/` folder over instead.

### 6. Database update (step 10)

Same PHP-path rule applies:

```bash
/opt/RZphp84/bin/php-cli maintenance/run.php update    # Strato
php maintenance/run.php update                          # generic
```

---

## Troubleshooting

- **Script stops mid-way:** read the last output line — with `set -e` it's the failing command (often a typo'd version number, a broken download URL, or a missing `composer.phar`).
- **"Extension missing" errors on the new wiki:** an extension from your `LocalSettings.php` isn't in the clone list — add its git URL and re-run, or clone it manually into `extensions/`.
- **Page looks unstyled / broken:** your skin or logo didn't make it over — check the step-4 copy block and your skin handling.
- **Uploads missing:** check that the `images` symlink points to your real uploads folder (`ls -l images`).
- **Extension doesn't support the new MediaWiki version:** the Gerrit `REL` branch won't exist (`git clone` fails) or the GitHub default branch may be incompatible — check the extension's compatibility table before updating.

---

## License &amp; disclaimer

Provided as-is, without any warranty. MediaWiki, its extensions and their repositories are subject to their respective licenses. Always back up your database before updating. This script was developed together with Mistral AI.
