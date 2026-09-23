package utils;

import net.datafaker.Faker;

import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

public class DataGenerator {

    private static final Faker faker = new Faker(new Locale("pt", "BR"));

    public static String getRandomName() {
        return faker.name().fullName();
    }

    public static String getRandomEmail() {
        String uniqueId = UUID.randomUUID().toString().substring(0, 8);
        return "user_" + System.currentTimeMillis() + "_" + uniqueId + "@example.com";
    }

    public static String getRandomUsername() {
        return faker.name().username() + "_" + UUID.randomUUID().toString().substring(0, 4);
    }

    public static String getRandomCpf() {
        return faker.cpf().valid();
    }

    public static String getRandomPhoneNumber() {
        return faker.phoneNumber().cellPhone();
    }

    public static String getRandomStreet() {
        return faker.address().streetAddress();
    }

    public static String getRandomCity() {
        return faker.address().city();
    }

    public static String getRandomZipCode() {
        return faker.address().zipCode();
    }

    /**
     * Gera uma senha alfanumérica com caracteres maiúsculos, minúsculos e dígitos
     * com o comprimento exato especificado.
     *
     * @param length comprimento exato da senha desejada
     * @return string de senha gerada
     */
    public static String generatePassword(int length) {
        if (length <= 0) {
            return "";
        }
        String seed = "Aa1!";
        if (length <= seed.length()) {
            return "Aa1!Bb2@".substring(0, length);
        }
        StringBuilder sb = new StringBuilder(seed);
        String pool = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        while (sb.length() < length) {
            int index = (int) (Math.random() * pool.length());
            sb.append(pool.charAt(index));
        }
        return sb.toString();
    }

    /**
     * Gera uma senha válida padrão com 12 caracteres.
     */
    public static String getRandomValidPassword() {
        return generatePassword(12);
    }

    public static Map<String, Object> getRandomUser() {
        Map<String, Object> user = new HashMap<>();
        user.put("name", getRandomName());
        user.put("username", getRandomUsername());
        user.put("email", getRandomEmail());
        user.put("phone", getRandomPhoneNumber());

        Map<String, String> address = new HashMap<>();
        address.put("street", getRandomStreet());
        address.put("city", getRandomCity());
        address.put("zipcode", getRandomZipCode());
        user.put("address", address);

        return user;
    }
}
