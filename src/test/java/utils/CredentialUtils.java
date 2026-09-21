package utils;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

public class CredentialUtils {

    public static String getEnv(String key, String defaultValue) {
        String value = System.getenv(key);
        if (value == null || value.trim().isEmpty()) {
            value = System.getProperty(key, defaultValue);
        }
        return value;
    }

    public static String getBasicAuthHeader(String username, String password) {
        String credentials = username + ":" + password;
        return "Basic " + Base64.getEncoder().encodeToString(credentials.getBytes(StandardCharsets.UTF_8));
    }

    public static String getBearerAuthHeader(String token) {
        return "Bearer " + token;
    }
}
