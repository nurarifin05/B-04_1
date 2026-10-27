#!/usr/bin/env bash
set -Eeuo pipefail
ACTION="${1:---install}"
LAB=/home/student/evidence
case "$ACTION" in --install|--reset|--status) ;; *) echo 'Usage: sudo bash setup.sh [--install|--reset|--status]'; exit 2;; esac
[[ $EUID -eq 0 ]] || { echo 'Jalankan menggunakan sudo'; exit 1; }
if [[ $ACTION == --status ]]; then
  for p in "$LAB/README.txt" "$LAB/notes/credentials.txt" "$LAB/archive/audit_portal.db" "$LAB/vault/audit_report.enc" "$LAB/vault/recovery_note.enc" "$LAB/integrity/sha256_manifest.txt"; do [[ -f $p ]] && echo "OK $p" || echo "MISSING $p"; done
  if command -v sqlite3 >/dev/null; then sqlite3 "$LAB/archive/audit_portal.db" '.tables' 2>/dev/null || :; fi
  exit 0
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq sqlite3 openssl hashcat unzip zip ca-certificates >/dev/null
if ! id student &>/dev/null; then useradd -m -s /bin/bash student; echo 'student:student123' | chpasswd; fi
mkdir -p "$LAB" /root/ctf-vm05-instructor
# Lab is resettable; preserve student account but refresh files
rm -rf "$LAB"; mkdir -p "$LAB"/{notes,archive,vault,integrity}
cat > "$LAB/README.txt" <<'EOF'
CTF VM-05 — Audit Portal Credential Leak (LAB SIMULASI)
Anda adalah analis keamanan yang menangani kebocoran arsip portal audit.
Folder notes/ memuat file .txt berisi kredensial latihan; archive/ memuat
SQLite; vault/ berisi dua berkas OpenSSL terenkripsi.
Semua akun, password, domain dan dokumen adalah data fiktif.
Lakukan investigasi tanpa mengubah database. Simpan hasil kerja di ~/work.
EOF
cat > "$LAB/notes/credentials.txt" <<'EOF'
# Salinan catatan pemindahan layanan (simulasi)
# SANGAT TIDAK AMAN: password ditulis secara plaintext pada file .txt.
service=portal_backup
username=backup_operator
password=Arsip#2026
endpoint=backup.audit.internal.test
note=kata sandi ini dipakai untuk recovery_note.enc, BUKAN untuk audit_report.enc
EOF
cat > "$LAB/notes/password_policy.txt" <<'EOF'
Pola password akun auditor_service dalam database:
5 huruf awal tetap: Audit
4 karakter terakhir adalah digit 0-9.
Pola hash: SHA-256 tanpa salt (hanya untuk pembelajaran; tidak aman untuk produksi).
Gunakan Hashcat mode 1400 dan mask attack -a 3.
EOF
DB="$LAB/archive/audit_portal.db"
PWHASH=$(printf '%s' 'Audit4826' | sha256sum | awk '{print $1}')
OTHERHASH=$(printf '%s' 'ExampleDontCrack' | sha256sum | awk '{print $1}')
sqlite3 "$DB" <<SQL
CREATE TABLE employees(id INTEGER PRIMARY KEY, username TEXT, division TEXT);
INSERT INTO employees VALUES(1,'auditor_service','Internal Audit'),(2,'backup_operator','Backup Ops');
CREATE TABLE portal_accounts(id INTEGER PRIMARY KEY, username TEXT, password_hash TEXT, status TEXT);
INSERT INTO portal_accounts VALUES(1,'auditor_service','$PWHASH','ACTIVE'),(2,'archived_admin','$OTHERHASH','DISABLED');
CREATE TABLE audit_events(event_id INTEGER PRIMARY KEY, action TEXT, actor TEXT);
INSERT INTO audit_events VALUES(101,'EXPORT_REQUEST','auditor_service');
CREATE TABLE archive_index(id INTEGER PRIMARY KEY, filename TEXT, classification TEXT);
INSERT INTO archive_index VALUES(1,'audit_report.enc','CONFIDENTIAL'),(2,'recovery_note.enc','INTERNAL');
SQL
# Encrypt two separate plaintext documents. Only ciphertext is retained in participant folder.
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
printf 'FLAG{AUDIT_REPORT_DECRYPTED_2026}\nCase: audit export approved for training.\n' > "$TMP/audit_report.txt"
printf 'FLAG{PLAINTEXT_CREDENTIAL_EXPOSED}\nFinding: backup password found in notes/credentials.txt\n' > "$TMP/recovery_note.txt"
openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -in "$TMP/audit_report.txt" -out "$LAB/vault/audit_report.enc" -pass pass:Audit4826
openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -in "$TMP/recovery_note.txt" -out "$LAB/vault/recovery_note.enc" -pass 'pass:Arsip#2026'
sha256sum "$LAB/vault/audit_report.enc" "$LAB/vault/recovery_note.enc" | sed "s|$LAB/||g" > "$LAB/integrity/sha256_manifest.txt"
cat > "$LAB/integrity/README.txt" <<'EOF'
Jalankan dari /home/student/evidence:
sha256sum -c integrity/sha256_manifest.txt
Hasil OK berarti berkas ciphertext tidak berubah, BUKAN berarti isinya aman.
EOF
cat > /root/ctf-vm05-instructor/answer_key.txt <<EOF
VM-05 - KUNCI INSTRUKTUR (JANGAN BAGIKAN)
1 FLAG{credentials.txt}
2 FLAG{backup_operator}
3 FLAG{Arsip#2026}
4 FLAG{audit_events_archive_index_employees_portal_accounts}
5 FLAG{auditor_service}
6 FLAG{$PWHASH}
7 FLAG{SHA256_MODE_1400}
8 FLAG{Audit4826}
9 FLAG{AUDIT_REPORT_DECRYPTED_2026}
10 FLAG{PLAINTEXT_CREDENTIAL_EXPOSED}
Integrity: sha256sum -c integrity/sha256_manifest.txt
EOF
chmod 700 /root/ctf-vm05-instructor; chmod 600 /root/ctf-vm05-instructor/answer_key.txt
chown -R student:student "$LAB"; chmod -R u+rwX,go+rX "$LAB"
echo '[OK] VM-05 siap. sudo bash setup.sh --status untuk memeriksa.'
