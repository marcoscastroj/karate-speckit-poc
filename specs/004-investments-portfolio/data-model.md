# Data Model: Gestão de Portfólio de Investimentos (Investments API)

**Feature**: `004-investments-portfolio`  
**Date**: 2026-09-28  
**Status**: Completed  

---

## 1. Diagrama Entidade-Relacionamento (ERD)

```mermaid
erDiagram
    USER ||--o{ INVESTMENT : "possui e custodia"
    USER ||--|| PORTFOLIO_SUMMARY : "possui consolidado"
    PORTFOLIO_SUMMARY ||--o{ CLASS_ALLOCATION : "agrega distribuicao"
    INVESTMENT }o--|| INVESTMENT_CLASS : "pertence a"
    CLASS_ALLOCATION }o--|| INVESTMENT_CLASS : "representa"

    USER {
        uuid id PK
        string email
        string nome_completo
    }

    INVESTMENT {
        uuid id PK
        uuid user_id FK
        string ticker "1 a 20 chars"
        string nome "1 a 255 chars"
        string classe "InvestmentClass Enum"
        string quantidade "decimal > 0.0"
        string preco_medio "decimal >= 0.0"
        string cotacao_atual "decimal >= 0.0"
        string total_investido "Calculado (qty * preco_medio)"
        string patrimonio_atual "Calculado (qty * cotacao_atual)"
        string lucro_prejuizo_absoluto "Calculado (patrimonio - total)"
        string rentabilidade_percentual "Calculado ((lucro / total) * 100)"
        datetime created_at
        datetime updated_at
    }

    PORTFOLIO_SUMMARY {
        string patrimonio_total "Soma patrimonio_atual dos ativos"
        string total_investido "Soma total_investido dos ativos"
        string lucro_prejuizo_absoluto "patrimonio_total - total_investido"
        string rentabilidade_percentual "((lucro / total) * 100)"
    }

    CLASS_ALLOCATION {
        string classe "InvestmentClass Enum"
        string patrimonio_total "Patrimonio total na classe"
        string total_investido "Total investido na classe"
        string percentual_carteira "(patrimonio_classe / total_carteira) * 100"
    }

    INVESTMENT_CLASS {
        string ACOES "Acoes e units"
        string FIIS "Fundos Imobiliarios"
        string RENDA_FIXA "Titulos publicos e privados"
        string CRIPTO "Criptomoedas e tokens"
        string ETF "Exchange Traded Funds"
        string RENDA_EMERGENCIAL "Reserva de liquidez"
    }
```

---

## 2. Entidades Detalhadas

### 2.1 Entidade: `Investment`

Representa a posição individual de custódia de um ativo no portfólio do usuário.

| Campo | Tipo | Obrigatoriedade | Regras de Validação & Restrições |
| :--- | :--- | :---: | :--- |
| `id` | UUID v4 | Sistema | Gerado na persistência; imutável via API. |
| `user_id` | UUID v4 | Sistema | Extraído exclusivamente do token Bearer JWT (`sub`). |
| `ticker` | String | Obrigatório | Min 1, Max 20 caracteres (ex: `"PETR4"`, `"BTC"`, `"HGLG11"`). |
| `nome` | String | Obrigatório | Min 1, Max 255 caracteres (ex: `"Petrobras PN"`). |
| `classe` | String (Enum) | Obrigatório | Restrito a: `ACOES`, `FIIS`, `RENDA_FIXA`, `CRIPTO`, `ETF`, `RENDA_EMERGENCIAL`. |
| `quantidade` | String/Number | Obrigatório | Estritamente maior que zero (`exclusiveMinimum: 0.0`). Regex: `^(?!^[-+.]*$)[+-]?0*\\d*\\.?\\d*$`. Suporta frações. |
| `preco_medio` | String/Number | Obrigatório | Maior ou igual a zero (`minimum: 0.0`). Custo médio unitário ponderado. |
| `cotacao_atual` | String/Number | Obrigatório | Maior ou igual a zero (`minimum: 0.0`). Valor de mercado unitário corrente. |
| `total_investido` | String | Read-Only | Computado: `quantidade * preco_medio`. |
| `patrimonio_atual` | String | Read-Only | Computado: `quantidade * cotacao_atual`. |
| `lucro_prejuizo_absoluto` | String | Read-Only | Computado: `patrimonio_atual - total_investido`. Permite valor negativo (prejuízo) ou positivo. |
| `rentabilidade_percentual` | String | Read-Only | Computado: `((patrimonio_atual - total_investido) / total_investido) * 100`. Se `total_investido == 0`, retorna `"0.00"`. |
| `created_at` | DateTime (ISO 8601)| Sistema | Timestamp de cadastro original da custódia. |
| `updated_at` | DateTime (ISO 8601)| Sistema | Timestamp da última atualização ou reavaliação de cotação. |

---

### 2.2 Entidade: `PortfolioSummary`

Consolidação dinâmica de toda a carteira de investimentos do usuário.

| Campo | Tipo | Descrição & Fórmula Matemática |
| :--- | :--- | :--- |
| `patrimonio_total` | String | $\sum \text{patrimonio\_atual}$ de todos os ativos do usuário logado. |
| `total_investido` | String | $\sum \text{total\_investido}$ de todos os ativos do usuário logado. |
| `lucro_prejuizo_absoluto` | String | $\text{patrimonio\_total} - \text{total\_investido}$. |
| `rentabilidade_percentual` | String | $((\text{patrimonio\_total} - \text{total\_investido}) / \text{total\_investido}) \times 100$. |
| `alocacao_por_classe` | Array[`ClassAllocation`] | Distribuição segregada por modalidade de investimento. Retorna `[]` quando carteira vazia. |

---

### 2.3 Entidade: `ClassAllocation`

Fatia patrimonial de uma classe dentro da carteira do usuário.

| Campo | Tipo | Descrição & Fórmula Matemática |
| :--- | :--- | :--- |
| `classe` | String (Enum) | Classe correspondente (`InvestmentClass`). |
| `patrimonio_total` | String | $\sum \text{patrimonio\_atual}$ dos ativos pertencentes a esta classe. |
| `total_investido` | String | $\sum \text{total\_investido}$ dos ativos pertencentes a esta classe. |
| `percentual_carteira` | String | $(\text{patrimonio\_total}_{\text{classe}} / \text{patrimonio\_total}_{\text{carteira}}) \times 100$. |

---

## 3. Ciclo de Vida e Transições de Estado

```mermaid
stateDiagram-v2
    [*] --> Inexistente
    Inexistente --> AtivoCustodiado : POST /api/v1/investments/ (Criação com cálculo inicial)
    AtivoCustodiado --> AtivoCustodiado : PUT /api/v1/investments/{id} (Atualização de cotação/preço/quantidade)
    AtivoCustodiado --> Excluido : DELETE /api/v1/investments/{id} (Desinvestimento / Liquidação)
    Excluido --> [*]

    state AtivoCustodiado {
        [*] --> LucroPositivo : cotacao > preco_medio
        [*] --> EmpateZero : cotacao == preco_medio
        [*] --> PrejuizoNegativo : cotacao < preco_medio
    }
```
