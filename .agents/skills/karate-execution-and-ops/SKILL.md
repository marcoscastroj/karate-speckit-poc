---
name: karate-execution-and-ops
description: >-
  Melhores práticas para execução, configuração de runner JUnit 5, paralelismo, filtragem por tags,
  comandos Maven CLI e análise de relatórios HTML no Karate DSL. Utilize ao executar testes,
  configurar pipelines de CI/CD, diagnosticar falhas de execução e otimizar threads paralelas.
---

# Karate Execution and Ops — Execução, Paralelismo e Relatórios

Este guia cobre a execução, orquestração paralela com JUnit 5, filtragem por tags e análise de diagnósticos e relatórios no **Karate DSL**.

---

## 1. ⚡ Arquitetura do Runner JUnit 5 (`TestRunner.java`)

O runner JUnit 5 centraliza a execução da suíte e o controle de threads paralelas:

```java
package features;

import com.intuit.karate.Results;
import com.intuit.karate.Runner;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

public class TestRunner {

    // Configuração de threads simultâneas para execução concorrente
    private static final int DEFAULT_THREAD_COUNT = 3;

    @Test
    void testAll() {
        int threads = Integer.getInteger("karate.threads", DEFAULT_THREAD_COUNT);
        Runner.Builder builder = Runner.path("classpath:features");

        String customTags = System.getProperty("karate.tags");
        if (customTags != null && !customTags.trim().isEmpty()) {
            // Se tags forem informadas (-Dkarate.tags="@smoke"), combina e exclui @ignore
            builder.tags(customTags, "~@ignore");
        } else {
            // Por padrão, ignora testes marcados como @ignore
            builder.tags("~@ignore");
        }

        Results results = builder.parallel(threads);

        // Asserção com mensagem de erro detalhada em caso de falha
        assertEquals(0, results.getFailCount(), results.getErrorMessages());
    }
}
```

---

## 2. 🏷️ Estratégia de Tags e Filtros

| Tag | Finalidade | Exemplo de Execução |
| :--- | :--- | :--- |
| `@smoke` | Happy path essencial e rápido (validação de sanidade do deploy) | `mvn test -Dkarate.tags="@smoke"` |
| `@regression` | Bateria completa de testes regressivos | `mvn test -Dkarate.tags="@regression"` |
| `@auth` | Todos os testes relacionados ao módulo de autenticação | `mvn test -Dkarate.tags="@auth"` |
| `@happy_path` | Apenas fluxos com retornos de sucesso (200, 201, 204) | `mvn test -Dkarate.tags="@happy_path"` |
| `@negative` | Apenas cenários negativos (400, 401, 403, 404, 409, 422) | `mvn test -Dkarate.tags="@negative"` |
| `@ignore` | Testes em quarentena ou helpers utilitários (nunca rodam sozinhos) | Excluídos automaticamente por `~@ignore` |

### Expressões Booleanas de Tags:
- **AND**: `@auth and @smoke`
- **OR**: `@smoke, @critical`
- **NOT**: `@regression and not @slow`

---

## 3. 🚀 Guia de Comandos Maven no Terminal

### Execução Padrão:
```bash
# Executa todos os testes em paralelo com 3 threads excluindo @ignore
mvn test
```

### Executar em Ambiente Específico (dev, qa, e2e):
```bash
# Alterna a baseUrl e timeouts para o bloco 'qa' do environments.json
mvn test -Dkarate.env=qa

# Alterna para ambiente e2e
mvn test -Dkarate.env=e2e
```

### Filtrar por Tags:
```bash
# Apenas testes de smoke
mvn test -Dkarate.tags="@smoke"

# Apenas testes do domínio de autenticação
mvn test -Dkarate.tags="@auth"

# Smoke tests excluindo cenários lentos
mvn test -Dkarate.tags="@smoke and not @slow"
```

### Executar uma Única Feature Isolada:
```bash
mvn test -Dtest=TestRunner -Dkarate.options="classpath:features/auth/register.feature"
```

### Ajustar Quantidade de Threads Paralelas:
```bash
mvn test -Dkarate.threads=5
```

### Passar Credenciais Seguras via Linha de Comando:
```bash
mvn test -DAPI_PASSWORD="meu-segredo-de-qa" -DAUTH_TOKEN="token-bearer-temporario"
```

---

## 4. 📊 Análise de Relatórios e Diagnósticos

Após a execução, o Karate gera relatórios interativos em HTML no diretório `target/karate-reports/`:

```
target/karate-reports/
├── karate-summary.html     # Relatório consolidado (suíte, features, % sucesso/falha, tempo total)
├── karate-timeline.html    # Gráfico visual de distribuição de threads paralelas no tempo
├── karate-tags.html        # Resultados agrupados por tags executadas
└── <feature-name>.html     # Detalhamento passo a passo de cada requisição e asserção HTTP
```

### Diagnóstico de Problemas:
1. **Falha de Asserção**:
   Abra `karate-summary.html`, clique na feature em vermelho e examine o diff JSON exibido na tela (o Karate aponta com precisão o campo divergente e a linha do schema).
2. **Gargalos de Performance / Threads Lentas**:
   Abra `karate-timeline.html`. Verifique se há uma thread bloqueada esperando resposta ou se cenários estão monopolizando a fila.
3. **Log Bruto de Execução**:
   Verifique `target/karate.log` para inspecionar os headers e corpos das requisições e respostas HTTP (conforme nível configurado no `logback-test.xml`).
