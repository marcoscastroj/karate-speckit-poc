package utils;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Properties;

public class CredentialUtils {

    private static Properties dotEnvProps = null;

    private static synchronized void loadDotEnvIfNeeded() {
        if (dotEnvProps != null) {
            return;
        }
        dotEnvProps = new Properties();

        // 1. Tenta carregar .env na raiz do projeto
        File envFile = new File(".env");
        if (!envFile.exists() || !envFile.isFile()) {
            // 2. Fallback para credentials.properties se .env nao existir
            envFile = new File("credentials.properties");
        }

        if (envFile.exists() && envFile.isFile()) {
            try (InputStream is = new FileInputStream(envFile)) {
                dotEnvProps.load(is);
            } catch (Exception ignored) {
                // Silencioso caso ocorra erro de I/O
            }
        }
    }

    public static String getEnv(String key, String defaultValue) {
        // 1. Variável de ambiente do sistema operacional (maior precedência)
        String value = System.getenv(key);
        if (value != null && !value.trim().isEmpty()) {
            return value;
        }

        // 2. JVM System Property (-Dkey=value)
        value = System.getProperty(key);
        if (value != null && !value.trim().isEmpty()) {
            return value;
        }

        // 3. Arquivo local .env ou credentials.properties
        loadDotEnvIfNeeded();
        if (dotEnvProps.containsKey(key)) {
            String fileVal = dotEnvProps.getProperty(key);
            if (fileVal != null && !fileVal.trim().isEmpty()) {
                return fileVal;
            }
        }

        // 4. Valor padrão de fallback
        return defaultValue;
    }

    public static String getBasicAuthHeader(String username, String password) {
        String credentials = username + ":" + password;
        return "Basic " + Base64.getEncoder().encodeToString(credentials.getBytes(StandardCharsets.UTF_8));
    }

    public static String getBearerAuthHeader(String token) {
        return "Bearer " + token;
    }
}

