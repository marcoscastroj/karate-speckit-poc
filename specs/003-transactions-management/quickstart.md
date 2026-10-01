# Quickstart: Gestão de Transações e Projeções Financeiras (Transactions API)

**Feature**: `specs/003-transactions-management/spec.md`  
**Status**: Concluído  
**Date**: 2026-09-28

---

## 🚀 Como Executar os Testes Automatizados

### Pré-requisitos
- **Java 21 LTS** instalado (`java -version`).
- **Maven 3.9+** instalado (`mvn -version`).
- Backend do Finance Organizer rodando no host `http://100.75.210.114:8000` (configurado em `src/test/resources/config/environments.json`).

---

## 🧪 Comandos de Execução (Maven CLI)

### 1. Executar Todos os Testes de Transações e Projeções em Paralelo (3 threads)
```bash
mvn test -Dkarate.tags="@transactions"
```

### 2. Executar por User Story Específica

* **User Story 1 - Registro de Transações (POST)**:
  ```bash
  mvn test -Dkarate.tags="@create and @transactions"
  ```

* **User Story 2 - Listagem e Filtros Combinados (GET list)**:
  ```bash
  mvn test -Dkarate.tags="@list and @transactions"
  ```

* **User Story 3 - Projeções e Totalizadores Mensais (GET /projections)**:
  ```bash
  mvn test -Dkarate.tags="@projections and @transactions"
  ```

* **User Story 4 - Consulta de Detalhes por ID (GET /id)**:
  ```bash
  mvn test -Dkarate.tags="@detail and @transactions"
  ```

* **User Story 5 - Exclusão e Reversão de Saldo (DELETE)**:
  ```bash
  mvn test -Dkarate.tags="@delete and @transactions"
  ```

---

## 📊 Relatório de Execução HTML

Após a conclusão dos testes, o relatório consolidado estará disponível em:
```text
target/karate-reports/karate-summary.html
```
Abra o arquivo diretamente no navegador para visualizar o payload exato, cabeçalhos HTTP e tempos de resposta de cada cenário.
