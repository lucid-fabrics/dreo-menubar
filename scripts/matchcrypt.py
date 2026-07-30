"""match EncryptionV2 (fastlane 2.2xx) encrypt/decrypt.

Format: base64( "match_encrypted_v2__" | salt(8) | auth_tag(16) | AES-256-GCM(ct) )
Key material: PBKDF2-HMAC-SHA256(pw, salt, 10000, 68) -> key(32) | iv(12) | auth_data(24)
"""
import base64, os, sys
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

HEADER = b'match_encrypted_v2__'

def _derive(pw, salt):
    kia = PBKDF2HMAC(algorithm=hashes.SHA256(), length=68, salt=salt, iterations=10000).derive(pw.encode())
    return kia[:32], kia[32:44], kia[44:68]

def decrypt(path, pw):
    data = base64.b64decode(open(path, 'rb').read().strip())
    if not data.startswith(HEADER):
        raise ValueError('not match_encrypted_v2: %s' % path)
    salt, tag, ct = data[20:28], data[28:44], data[44:]
    key, iv, ad = _derive(pw, salt)
    return AESGCM(key).decrypt(iv, ct + tag, ad)

def encrypt(plaintext: bytes, pw: str) -> bytes:
    salt = os.urandom(8)
    key, iv, ad = _derive(pw, salt)
    sealed = AESGCM(key).encrypt(iv, plaintext, ad)
    ct, tag = sealed[:-16], sealed[-16:]
    blob = HEADER + salt + tag + ct
    return base64.b64encode(blob)

def _self_check():
    """Round-trips synthetic data. Proves the format is symmetric, needs no repo."""
    import tempfile
    pw = 'correct horse battery staple'
    payload = b'-----BEGIN RSA PRIVATE KEY-----\nnot a real key\n' + os.urandom(64)
    with tempfile.NamedTemporaryFile(suffix='.enc', delete=False) as f:
        f.write(encrypt(payload, pw))
        path = f.name
    try:
        assert decrypt(path, pw) == payload, 'round-trip mismatch'
        blob = base64.b64decode(open(path, 'rb').read())
        assert blob.startswith(HEADER), 'header missing'
        assert len(blob) == 20 + 8 + 16 + len(payload), 'unexpected framing'
        try:
            decrypt(path, pw + 'x')
        except Exception:
            pass
        else:
            raise AssertionError('wrong password should not decrypt')
    finally:
        os.remove(path)
    print('self-check OK: match V2 round-trips and rejects a wrong password')


if __name__ == '__main__':
    # `matchcrypt.py`                       -> self-check
    # `matchcrypt.py <file> <password>`     -> decrypt a real match file to stdout
    if len(sys.argv) == 1:
        _self_check()
    elif len(sys.argv) == 3:
        sys.stdout.buffer.write(decrypt(sys.argv[1], sys.argv[2]))
    else:
        sys.exit('usage: matchcrypt.py [<encrypted-file> <password>]')
