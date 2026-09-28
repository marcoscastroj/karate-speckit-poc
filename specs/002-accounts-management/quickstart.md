# Quickstart: Execução e Validação dos Testes da Accounts API

**Branch**: `002-accounts-management` | **Feature**: [specs/002-accounts-management/spec.md](spec.md)

Este guia prático descreve como executar e validar localmente a suíte de testes de automação de API do módulo **Accounts** em Karate DSL.

---

## 1. ⚙️ Pré-requisitos

1. **Java 21 LTS** instalado e configurado no `PATH` (`java -version`).
2. **Maven 3.8+** instalado (`mvn -version`).
3. **API Finance Organizer** em execução no host padrão configurado em `environments.json`:
   ```bash
   curl -s http://100.75.210.114:8000/docs > /dev/null && echo "API Online" || echo "API Indisponível"
   ```

---

## 2. 🚀 Comandos de Execução dos Testes via Maven

### Executar Toda a Bateria do Módulo Accounts:
```bash
# Executa todas as features marcadas com @accounts em paralelo (3 threads)
mvn test -Dkarate.tags="@accounts"
```

### Executar Apenas Smoke Tests (Cenários Críticos):
```bash
mvn test -Dkarate.tags="@accounts and @smoke"
```

### Executar Validações Negativas e Limites de Borda:
```bash
mvn test -Dkarate.tags="@accounts and @negative"
```

### Executar Apenas Testes de Segurança e IDOR:
```bash
mvn test -Dkarate.tags="@accounts and @idor"
```

### Executar uma Feature Específica Isoladamente:
```bash
# Exemplo: Testar apenas a criação de contas
mvn test -Dtest=TestRunner -Dkarate.options="classpath:features/accounts/accounts-create.feature"
```

---

## 3. 📊 Relatórios e Diagnóstico

Após a execução, o relatório consolidado em HTML estará disponível em:
```text
target/karate-reports/karate-summary.html
```

Para verificar o gráfico de execução concorrente e distribuição de threads paralelas:
```text
target/karate-reports/karate-timeline.html
```
