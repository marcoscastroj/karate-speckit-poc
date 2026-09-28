# Quickstart: Gestão de Portfólio de Investimentos (Investments API)

**Feature**: `specs/004-investments-portfolio/spec.md`  
**Status**: Concluído  
**Date**: 2026-09-28

---

## 🚀 Como Executar os Testes Automatizados

### Pré-requisitos
- **Java 21 LTS** instalado e configurado (`java -version`).
- **Maven 3.9+** instalado (`mvn -version`).
- API do Finance Organizer rodando no host baseline `http://100.75.210.114:8000` (declarado em `src/test/resources/config/environments.json`).

---

## 🧪 Comandos de Execução (Maven CLI)

### 1. Executar Toda a Suíte de Investimentos (Paralelo - 3 threads)
```bash
mvn test -Dkarate.tags="@investments"
```

### 2. Executar Cenários Críticos (Smoke Tests)
```bash
mvn test -Dkarate.tags="@investments and @smoke"
```

### 3. Executar por Operação / User Story Específica

* **User Story 1 - Registo de Posições (POST)**:
  ```bash
  mvn test -Dkarate.tags="@create and @investments"
  ```

* **User Story 2 - Resumo Consolidado do Portfólio (GET /summary)**:
  ```bash
  mvn test -Dkarate.tags="@summary and @investments"
  ```

* **User Story 3 - Listagem e Filtros por Classe (GET list)**:
  ```bash
  mvn test -Dkarate.tags="@list and @investments"
  ```

* **User Story 4 - Detalhes da Posição por ID (GET /{id})**:
  ```bash
  mvn test -Dkarate.tags="@detail and @investments"
  ```

* **User Story 5 - Atualização e Recálculo (PUT /{id})**:
  ```bash
  mvn test -Dkarate.tags="@update and @investments"
  ```

* **User Story 6 - Exclusão de Custódia (DELETE /{id})**:
  ```bash
  mvn test -Dkarate.tags="@delete and @investments"
  ```

* **Testes de Segurança e Proteção Anti-IDOR (Multi-tenancy)**:
  ```bash
  mvn test -Dkarate.tags="@idor and @investments"
  ```

---

## 📊 Relatório de Execução HTML

Após a conclusão da execução, o relatório interativo de evidências estará disponível em:
```text
target/karate-reports/karate-summary.html
```
Abra o arquivo diretamente em seu navegador para inspecionar requisições, respostas, asserções de contrato, tempos de execução e rastros de execução paralela.
