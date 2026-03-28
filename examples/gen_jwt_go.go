// Go example: HKDF-SHA256 derive 32-byte key then sign HS256
package main

import (
    "crypto/hmac"
    "crypto/sha256"
    "encoding/base64"
    "fmt"
    "os"
    "time"
    "bytes"
)

func hkdfExtract(salt, ikm []byte) []byte {
    mac := hmac.New(sha256.New, salt)
    mac.Write(ikm)
    return mac.Sum(nil)
}

func hkdfExpand(prk []byte, info []byte, outLen int) []byte {
    var okm []byte
    t := []byte{}
    ctr := byte(1)
    for len(okm) < outLen {
        mac := hmac.New(sha256.New, prk)
        mac.Write(t)
        mac.Write(info)
        mac.Write([]byte{ctr})
        t = mac.Sum(nil)
        okm = append(okm, t...)
        ctr++
    }
    return okm[:outLen]
}

func deriveSecret(secret []byte) []byte {
    if len(secret) < 32 {
        prk := hkdfExtract([]byte{}, secret)
        return hkdfExpand(prk, []byte("hs256-derivation"), 32)
    }
    return secret
}

func main() {
    secret := []byte("dev-secret")
    if len(os.Args) > 1 {
        secret = []byte(os.Args[1])
    }
    finalSecret := deriveSecret(secret)
    // Example: create a very simple base64url HMAC-SHA256 signature over header.payload
    header := `{"alg":"HS256","typ":"JWT"}`
    payload := fmt.Sprintf(`{"sub":"testuser","exp":%d}`, time.Now().Unix()+3600)
    signingInput := base64.RawURLEncoding.EncodeToString([]byte(header)) + "." + base64.RawURLEncoding.EncodeToString([]byte(payload))
    mac := hmac.New(sha256.New, finalSecret)
    mac.Write([]byte(signingInput))
    sig := mac.Sum(nil)
    sigB64 := base64.RawURLEncoding.EncodeToString(sig)
    token := signingInput + "." + sigB64
    fmt.Println(token)
}
