package features;

import com.intuit.karate.Results;
import com.intuit.karate.Runner;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

public class TestRunner {

    private static final int THREAD_COUNT = 3;

    @Test
    void testAll() {
        Runner.Builder builder = Runner.path("classpath:features");

        String customTags = System.getProperty("karate.tags");
        if (customTags != null && !customTags.trim().isEmpty()) {
            // Suporta múltiplas tags combinadas com 'and' (ex: '@investments and @smoke')
            String[] tags = customTags.split("\\s+and\\s+");
            for (String tag : tags) {
                if (!tag.trim().isEmpty()) {
                    builder.tags(tag.trim());
                }
            }
            builder.tags("~@ignore");
        } else {
            // Por padrão, ignora qualquer cenário ou feature marcado com @ignore
            builder.tags("~@ignore");
        }

        // Executa em paralelo com 3 threads
        Results results = builder.parallel(THREAD_COUNT);

        assertEquals(0, results.getFailCount(), results.getErrorMessages());
    }
}
