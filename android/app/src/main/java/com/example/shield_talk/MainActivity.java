package com.example.shield_talk;

import android.os.Build;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import java.io.IOException;
import java.security.*;
import java.security.cert.CertificateException;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;

public class MainActivity extends FlutterActivity {

    private static final String CHANNEL_NAME = "com.shieldtalk/security_channel";
    private static final String RSA_ALGORITHM = "RSA/ECB/PKCS1Padding";
    private static final String AES_ALGORITHM = "AES/ECB/PKCS5Padding";
    private static final String SYMMETRIC_KEY_ALGORITHM = "AES";
    private static final String ASYMMETRIC_KEY_ALGORITHM = "RSA";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_NAME)
                .setMethodCallHandler(
                        (call, result) -> {
                            switch (call.method) {
                                case "encryptKey":
                                    result.success(encryptKey(call.argument("keyToEncrypt"), call.argument("publicKey")));
                                    break;
                                case "decryptMessage":
                                    result.success(decryptMessage(call.argument("key"), call.argument("message")));
                                    break;
                                case "generateKeys":
                                    result.success(generateKeys());
                                    break;
                                case "decryptKey":
                                    result.success(decryptKeyCopy(call.argument("keyToDecrypt"), call.argument("privateKey")));
                                    break;
                                case "generateSymmetricKey":
                                    try {
                                        result.success(generateSymmetricKey());
                                    } catch (NoSuchAlgorithmException e) {
                                        e.printStackTrace();
                                    }
                                    break;
                                case "encryptMessage":
                                    try {
                                        result.success(encryptMessage(call.argument("key"), call.argument("message")));
                                    } catch (UnrecoverableKeyException e) {
                                        result.success(e.toString());
                                    } catch (CertificateException e) {
                                        result.success(e.toString());
                                    } catch (KeyStoreException e) {
                                        result.success(e.toString());
                                    } catch (NoSuchAlgorithmException e) {
                                        result.success(e.toString());
                                    } catch (IOException e) {
                                        result.success(e.toString());
                                    }
                                    break;
                                default:
                                    result.notImplemented();
                                    break;
                            }
                        });
    }

    private PrivateKey getPrivateKey(byte[] privateKey) {
        try {
            return KeyFactory.getInstance(ASYMMETRIC_KEY_ALGORITHM).generatePrivate(new PKCS8EncodedKeySpec(privateKey));
        } catch (Exception e) {
            return null;
        }
    }

    private String encryptMessage(byte[] encryptionKey, String messageToEncrypt) throws UnrecoverableKeyException, CertificateException, KeyStoreException, NoSuchAlgorithmException, IOException {
        try {
            Cipher cipher = Cipher.getInstance(AES_ALGORITHM);
            cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(encryptionKey, SYMMETRIC_KEY_ALGORITHM));
            byte[] plainText = cipher.doFinal(messageToEncrypt.getBytes());
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                return new String(Base64.getEncoder().encode(plainText));
            }
            return new String(plainText);
        } catch (Exception e) {
            e.printStackTrace();
            return e + ", Private key is null";
        }
    }

    private String decryptMessage(byte[] decryptionKey, String encryptedMessage) {
        try {
            Cipher cipher = Cipher.getInstance(AES_ALGORITHM);
            cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(decryptionKey, SYMMETRIC_KEY_ALGORITHM));
            byte[] plainText = new byte[0];
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                plainText = cipher.doFinal(Base64.getDecoder().decode(encryptedMessage));
            }
            return new String(plainText);
        } catch (Exception e) {
            return e.toString();
        }
    }

    private byte[] encryptKey(byte[] keyToEncrypt, byte[] publicKey) {
        try {
            PublicKey key = KeyFactory.getInstance(ASYMMETRIC_KEY_ALGORITHM).generatePublic(new X509EncodedKeySpec(publicKey));
            Cipher cipher = Cipher.getInstance(RSA_ALGORITHM);
            cipher.init(Cipher.ENCRYPT_MODE, key);
            return cipher.doFinal(keyToEncrypt);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return new byte[]{};
    }

    private SecretKey decryptKey(byte[] keyToDecrypt, byte[] privateKey) {
        try {
            PrivateKey key = getPrivateKey(privateKey);
            Cipher cipher = Cipher.getInstance(RSA_ALGORITHM);
            cipher.init(Cipher.DECRYPT_MODE, key);
            return new SecretKeySpec(cipher.doFinal(keyToDecrypt), SYMMETRIC_KEY_ALGORITHM);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
    }

    private byte[] decryptKeyCopy(byte[] keyToDecrypt, byte[] privateKey) {
        try {
            PrivateKey key = getPrivateKey(privateKey);
            Cipher cipher = Cipher.getInstance(RSA_ALGORITHM);
            cipher.init(Cipher.DECRYPT_MODE, key);
            return new SecretKeySpec(cipher.doFinal(keyToDecrypt), SYMMETRIC_KEY_ALGORITHM).getEncoded();
        } catch (Exception e) {
            e.printStackTrace();
        }
        return new byte[]{0,3};
    }

    private byte[] generateSymmetricKey() throws NoSuchAlgorithmException {
        int n = 256;
        KeyGenerator keyGenerator = KeyGenerator.getInstance(SYMMETRIC_KEY_ALGORITHM);
        keyGenerator.init(n);
        return keyGenerator.generateKey().getEncoded();
    }

    private ArrayList<String> generateKeys() {
        try {
            KeyPairGenerator keyPairGenerator = KeyPairGenerator.getInstance(ASYMMETRIC_KEY_ALGORITHM);
            keyPairGenerator.initialize(2048);
            KeyPair pair = keyPairGenerator.generateKeyPair();
            byte[] publicKey = pair.getPublic().getEncoded();
            byte[] privateKey = pair.getPrivate().getEncoded();
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                return new ArrayList<>(Arrays.asList(Base64.getEncoder().encodeToString(privateKey), Base64.getEncoder().encodeToString(publicKey)));
            }
        } catch (Exception e) {
            e.printStackTrace();
            return new ArrayList<>(Arrays.asList("", ""));
        }
        return new ArrayList<>(Arrays.asList("Build version not good", "Build version not good"));
    }
}
