// Node.js example: HKDF-SHA256 derive 32-byte key then sign HS256
const crypto = require('crypto');
const jwt = require('jsonwebtoken');

function hkdfExtract(salt, ikm) {
  return crypto.createHmac('sha256', salt).update(ikm).digest();
}

function hkdfExpand(prk, info, outLen) {
  let okm = Buffer.alloc(0);
  let t = Buffer.alloc(0);
  let i = 1;
  const infoBuf = Buffer.from(info);
  while (okm.length < outLen) {
    t = crypto.createHmac('sha256', prk).update(Buffer.concat([t, infoBuf, Buffer.from([i])])).digest();
    okm = Buffer.concat([okm, t]);
    i += 1;
  }
  return okm.slice(0, outLen);
}

function deriveSecret(secret) {
  const secretBuf = Buffer.isBuffer(secret) ? secret : Buffer.from(secret);
  if (secretBuf.length < 32) {
    const prk = hkdfExtract(Buffer.alloc(0), secretBuf);
    return hkdfExpand(prk, 'hs256-derivation', 32);
  }
  return secretBuf;
}

// Usage example
const secret = process.argv[2] || 'dev-secret';
const finalSecret = deriveSecret(secret);
const payload = { sub: 'testuser', exp: Math.floor(Date.now()/1000) + 3600 };
const headers = { alg: 'HS256', typ: 'JWT' };
const token = jwt.sign(payload, finalSecret, { algorithm: 'HS256', header: headers });
console.log(token);
