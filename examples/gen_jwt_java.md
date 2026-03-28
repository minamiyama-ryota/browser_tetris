Java example (JJWT) — HKDF派生 → HS256署名

以下は概念サンプル。プロジェクトに `io.jsonwebtoken:jjwt-api` 等の依存を追加して利用してください。

```java
// HKDF-SHA256 実装（簡易） + JJWT による署名
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.util.Base64;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;

public class GenJwt {
    public static byte[] hkdfExtract(byte[] salt, byte[] ikm) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(salt, "HmacSHA256"));
        return mac.doFinal(ikm);
    }

    public static byte[] hkdfExpand(byte[] prk, byte[] info, int outLen) throws Exception {
        byte[] okm = new byte[0];
        byte[] t = new byte[0];
        int i = 1;
        while (okm.length < outLen) {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(prk, "HmacSHA256"));
            mac.update(t);
            mac.update(info);
            mac.update((byte)i);
            t = mac.doFinal();
            byte[] newOkm = new byte[okm.length + t.length];
            System.arraycopy(okm, 0, newOkm, 0, okm.length);
            System.arraycopy(t, 0, newOkm, okm.length, t.length);
            okm = newOkm;
            i++;
        }
        byte[] out = new byte[outLen];
        System.arraycopy(okm, 0, out, 0, outLen);
        return out;
    }

    public static void main(String[] args) throws Exception {
        byte[] secret = "dev-secret".getBytes("UTF-8");
        byte[] finalSecret = secret.length < 32 ? hkdfExpand(hkdfExtract(new byte[0], secret), "hs256-derivation".getBytes("UTF-8"), 32) : secret;
        String token = Jwts.builder().setSubject("testuser").signWith(SignatureAlgorithm.HS256, finalSecret).compact();
        System.out.println(token);
    }
}
```
