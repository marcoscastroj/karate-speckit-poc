package utils;

import net.datafaker.Faker;

import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

public class DataGenerator {

    private static final Faker faker = new Faker(new Locale("pt", "BR"));

    public static String getRandomName() {
        return faker.name().fullName();
    }

    public static String getRandomEmail() {
        return faker.internet().emailAddress();
    }

    public static String getRandomUsername() {
        return faker.name().username();
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
