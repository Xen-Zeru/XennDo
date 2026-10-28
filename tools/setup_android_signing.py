#!/usr/bin/env python3
"""Owner-run signing setup. Passwords are entered only in the owner's terminal.

Run: python3 tools/setup_android_signing.py
Creates a PKCS12 release key outside the repository, or reuses an existing key.
Never overwrites a keystore or key.properties; never prints password values.
"""

import getpass
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import warnings

ROOT = Path(__file__).resolve().parents[1]
SIGNING_DIR = Path.home() / '.local' / 'share' / 'xenndo-signing'
CONFIG = ROOT / 'android' / 'key.properties'


def property_value(value):
    """Escape Java Properties (including UTF-16 escapes for non-ASCII values)."""
    encoded = []
    for char in value:
        if char in '\\ :=#!':
            encoded.append('\\' + char)
        elif 32 <= ord(char) <= 126:
            encoded.append(char)
        else:
            utf16 = char.encode('utf-16-be')
            encoded.extend('\\u' + utf16[i:i + 2].hex() for i in range(0, len(utf16), 2))
    return ''.join(encoded)


def run_keytool(arguments, password):
    # An inherited anonymous pipe supplies the password. Neither argv nor the
    # environment contains it, and no password file is written to disk.
    read_fd, write_fd = os.pipe()
    try:
        os.write(write_fd, (password + '\n').encode('utf-8'))
    finally:
        os.close(write_fd)
    try:
        result = subprocess.run(
            [shutil.which('keytool'), '-J-Duser.language=en', '-J-Duser.country=US',
             *arguments, '-storepass:file', f'/dev/fd/{read_fd}'],
            pass_fds=(read_fd,), capture_output=True, check=False,
        )
    finally:
        os.close(read_fd)
    if result.returncode != 0:
        raise RuntimeError('keytool failed. Check the entered password, alias and certificate subject. No signing configuration was written.')
    return result.stdout


def main():
    if not sys.stdin.isatty() or not sys.stderr.isatty():
        raise RuntimeError('Run this helper in your own interactive terminal, not an agent tool or redirected command.')
    warnings.simplefilter('error', getpass.GetPassWarning)
    if not shutil.which('keytool'):
        raise RuntimeError('Install a JDK with keytool first.')
    if CONFIG.exists() or CONFIG.is_symlink():
        raise RuntimeError('android/key.properties already exists; refusing to overwrite private signing configuration.')
    ignored = subprocess.run(['git', 'check-ignore', '-q', 'android/key.properties'], cwd=ROOT, check=False)
    if ignored.returncode != 0:
        raise RuntimeError('android/key.properties must be ignored by Git before setup.')
    os.umask(0o077)
    SIGNING_DIR.mkdir(parents=True, exist_ok=True)
    if SIGNING_DIR.resolve().is_relative_to(ROOT):
        raise RuntimeError('Signing directory must be outside the repository.')
    SIGNING_DIR.chmod(0o700)
    print('Passwords stay in this terminal. Store them in your password manager, not chat.')
    print('This key signs direct-distribution APKs and must be retained for future updates.')
    mode = input('Create a new key or reuse your existing production key? [create/reuse]: ').strip().lower()
    if mode not in {'create', 'reuse'}:
        raise RuntimeError('Enter create or reuse; no key was generated.')
    if mode == 'create':
        keystore = SIGNING_DIR / 'xenndo-release.p12'
        if keystore.exists() or keystore.is_symlink():
            raise RuntimeError('Release keystore already exists. Restart and choose reuse; do not replace it.')
    else:
        keystore = Path(input('Existing production keystore path (outside this repository): ').strip()).expanduser().resolve()
        if not keystore.is_file():
            raise RuntimeError('The selected keystore does not exist.')
    if keystore.resolve().is_relative_to(ROOT) or keystore.name.lower() == 'debug.keystore':
        raise RuntimeError('Use a production keystore outside the repository, not debug.keystore.')
    alias = input('Production key alias [xenndo-release]: ').strip() or 'xenndo-release'
    if alias.lower() == 'androiddebugkey' or any(ord(c) < 32 for c in alias):
        raise RuntimeError('Use a production key alias, not the Android debug alias.')
    password = getpass.getpass('Keystore password (hidden): ')
    if not password or len(password.encode('utf-8')) > 1024 or any(ord(c) < 32 for c in password):
        raise RuntimeError('Use a non-empty password without control characters (at most 1024 UTF-8 bytes).')
    if mode == 'create':
        if len(password) < 12 or not password.isascii():
            raise RuntimeError('Choose at least 12 printable ASCII characters for the new PKCS12 password.')
        if password != getpass.getpass('Confirm keystore password (hidden): '):
            raise RuntimeError('Passwords differ; no key was generated.')
        subject = input('Public certificate subject (for example CN=Xen-Zeru): ').strip()
        if not subject.startswith('CN='):
            raise RuntimeError('Supply your public certificate subject starting with CN=. No key was generated.')
        run_keytool(['-genkeypair', '-keystore', str(keystore), '-storetype', 'PKCS12',
                     '-alias', alias, '-keyalg', 'RSA', '-keysize', '3072', '-sigalg',
                     'SHA256withRSA', '-validity', '10000', '-dname', subject], password)
        key_password = password  # PKCS12 uses the same key/store password.
    else:
        key_password = getpass.getpass('Private-key password (hidden; Enter if same as keystore): ') or password
    listing = run_keytool(['-list', '-v', '-keystore', str(keystore), '-alias', alias], password).decode('utf-8', errors='replace')
    if 'PrivateKeyEntry' not in listing or 'CN=Android Debug' in listing:
        raise RuntimeError('Select a production PrivateKeyEntry, not an Android debug certificate.')
    certificate = run_keytool(['-exportcert', '-keystore', str(keystore), '-alias', alias], password)
    fingerprint = hashlib.sha256(certificate).hexdigest()
    # Preserve an independent public certificate for later APK identity checks.
    public_path = SIGNING_DIR / (fingerprint + '.der')
    if public_path.exists() and public_path.read_bytes() != certificate:
        raise RuntimeError('Existing public certificate differs; refusing to replace it.')
    public_path.write_bytes(certificate)
    public_path.chmod(0o600)
    keystore.chmod(0o600)
    properties = {'storeFile': str(keystore.resolve()), 'storePassword': password,
                  'keyAlias': alias, 'keyPassword': key_password}
    with CONFIG.open('x', encoding='ascii') as output:
        output.write('# Private local signing configuration. Never commit or upload.\n')
        for key, value in properties.items():
            output.write(key + '=' + property_value(value) + '\n')
        output.flush()
        os.fsync(output.fileno())
    CONFIG.chmod(0o600)
    print('Signing configuration saved privately; no password values printed.')
    print('Keystore:', keystore)
    print('Public certificate:', public_path)
    print('Certificate SHA-256:', fingerprint)
    print('Back up the keystore in encrypted offline storage and save passwords/alias in your password manager.')
    print('Keep a second protected copy and verify recovery. Do not send these files or passwords in chat.')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, KeyboardInterrupt, EOFError, getpass.GetPassWarning) as error:
        print('Setup stopped:', error, file=sys.stderr)
        sys.exit(1)
