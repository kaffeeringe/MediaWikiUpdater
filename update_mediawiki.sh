#!/bin/bash
set -e

# ==========================================
# KONFIGURATION
# Standard-Variablen für Versionen anpassen!
# ==========================================
OLD_VER="1.45.1"
NEW_VER="1.46.2"
MAJOR_VER="1.46" # z. B. 1.42 für tar.gz Pfade

# 1. Herunterladen der neuen MediaWiki-Version
echo "==> [1/10] Lade MediaWiki $NEW_VER herunter..."
wget -q --show-progress "https://releases.wikimedia.org/mediawiki/${MAJOR_VER}/mediawiki-${NEW_VER}.tar.gz"

# 2. Entpacken im neuen Ordner mediawiki-NEUEVERSIONSNUMMER
echo "==> [2/10] Entpacke MediaWiki..."
tar -xzf "mediawiki-${NEW_VER}.tar.gz"
rm "mediawiki-${NEW_VER}.tar.gz"

# 3. In alten Ordner wechseln
echo "==> [3/10] Wechsle in den alten Ordner..."
cd "mediawiki-${OLD_VER}"

# 4. Bild-Datei kopieren
echo "==> [4/10] Kopiere Logo, FavIcon und .htaccess ..."
if [ -f "wiki.png" ]; then
    cp wiki.png "../mediawiki-${NEW_VER}/"
    cp favicon.ico "../mediawiki-${NEW_VER}/"
    cp .htaccess "../mediawiki-${NEW_VER}/"
    cp googlec9230c811948caa1.html "../mediawiki-${NEW_VER}/"
fi

# 5. In den neuen Ordner wechseln
echo "==> [5/10] Wechsle in neuen Ordner mediawiki-${NEW_VER}..."
cd "../mediawiki-${NEW_VER}"

# 6. images/-Ordner im neuen Verzeichnis löschen
echo "==> [6/10] Entferne Standard-images Ordner..."
rm -rf images/

# 7. Symlink zum bestehenden zentralen images/-Ordner erstellen und zum Matomo Verzeichnis
echo "==> [7/10] Erstelle Symlink für images/..."
ln -s ../images images
ln -s ../matomo stats

# 8. Drittanbieter-Extensions per git clonen
echo "==> Klone Extensions passend für MediaWiki REL${MAJOR_VER//./_}..."
cd extensions/

# 1. Gerrit-Extensions: Nutzen dynamisch den passenden REL-Branch der Major-Version
git clone -b "REL${MAJOR_VER//./_}" https://gerrit.wikimedia.org/r/mediawiki/extensions/Arrays.git
git clone -b "REL${MAJOR_VER//./_}" https://gerrit.wikimedia.org/r/mediawiki/extensions/ConfirmAccount.git
git clone -b "REL${MAJOR_VER//./_}" https://gerrit.wikimedia.org/r/mediawiki/extensions/Lockdown.git
git clone -b "REL${MAJOR_VER//./_}" https://gerrit.wikimedia.org/r/mediawiki/extensions/MagicNoCache.git
git clone -b "REL${MAJOR_VER//./_}" https://gerrit.wikimedia.org/r/mediawiki/extensions/RealMe.git
git clone -b "REL${MAJOR_VER//./_}" https://gerrit.wikimedia.org/r/mediawiki/extensions/UserMerge.git
git clone -b "REL${MAJOR_VER//./_}" https://gerrit.wikimedia.org/r/mediawiki/extensions/Variables.git
git clone -b "REL${MAJOR_VER//./_}" https://gerrit.wikimedia.org/r/mediawiki/extensions/UploadWizard.git
git clone -b "REL${MAJOR_VER//./_}" https://gerrit.wikimedia.org/r/mediawiki/extensions/Popups.git
git clone -b "REL${MAJOR_VER//./_}" https://gerrit.wikimedia.org/r/mediawiki/extensions/Description2.git
git clone -b "REL${MAJOR_VER//./_}" https://gerrit.wikimedia.org/r/mediawiki/extensions/OpenGraphMeta.git
git clone -b "REL${MAJOR_VER//./_}" https://gerrit.wikimedia.org/r/mediawiki/extensions/ExternalData.git

# 2. Externe GitHub-Extensions (nutzen standardmäßig ihre eigenen Main/Master- oder Release-Stränge)
# git clone https://github.com/Universal-Omega/DynamicPageList4.git
git clone https://github.com/Wikia/mediawiki-extensions-EmbedVideo.git EmbedVideo
git clone https://github.com/ProfessionalWiki/Maps.git
git clone https://github.com/miraheze/MatomoAnalytics.git
git clone https://github.com/mywikis/CrawlerProtection.git

# Automatischer Composer-Durchlauf für alle Extensions, die eine composer.json besitzen
echo "==> Prüfe und installiere Composer-Abhängigkeiten für Extensions..."
for ext_dir in */; do
    if [ -f "${ext_dir}composer.json" ]; then
        echo "--> Installiere Abhängigkeiten für Extension: ${ext_dir%/}"
        /opt/RZphp84/bin/php-cli ../../composer.phar config -d "${ext_dir%/}" policy.advisories.block false 2>/dev/null
        # 2. Abhängigkeiten ohne Dev-Pakete installieren
        /opt/RZphp84/bin/php-cli ../../composer.phar install -d "${ext_dir%/}" --no-dev --optimize-autoloader --ignore-platform-reqs
    fi
done

cd ..

# 9. LocalSettings.php kopieren
echo "==> [9/10] Kopiere LocalSettings.php..."
cp "../mediawiki-${OLD_VER}/LocalSettings.php" ./

# 10. Wartungs-/Update-Skript ausführen
echo "==> [10/10] Führe Datenbank-Update aus..."
/opt/RZphp84/bin/php-cli  maintenance/run.php update

echo "=========================================="
echo " Update erfolgreich abgeschlossen! "
echo "=========================================="
