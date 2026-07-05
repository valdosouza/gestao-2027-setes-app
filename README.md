# setes-app — Flutter Web/Android/iOS (Gestão 2027)

Monorepo do front-end do ERP Setes. **Prompt da fase**: `D:\Gestao2027\Infra-IA\setes-app\prompt_fase1_fundacao.md` (24 decisões — os números citados nos comentários do código referem-se a elas).

## Estrutura (decisão 10)

```
setes-app/
├── pubspec.yaml            # pub workspace (Dart 3.6+): um resolve para tudo
├── packages/
│   ├── core/               # auth, menus, http, responsive, prefs locais
│   └── setes_widgets/      # design system: telas usam SÓ widgets Setes* (decisão 11)
└── apps/
    └── web/                # shell multi-módulos com menus dinâmicos
```

Fases futuras: `apps/budget_sales`, `apps/stock_count`, `apps/budget_autocenter`, `apps/erp_authorization` (com.setes.*) e deploy iOS (decisão 9).

## Primeira execução

```bash
cd setes-app
flutter pub get                      # resolve o workspace inteiro

cd apps/web
flutter create --platforms web .     # gera a pasta web/ (index.html etc.) — só na 1ª vez
flutter run -d chrome --dart-define=API_URL=http://localhost:3000
```

Pré-requisito: setes-api rodando na porta 3000 (com sql/01 aplicado e migration 003 executada).

## Comandos (Agent_Context_App.md — decisão 12)

| Objetivo | Comando |
|---|---|
| Testes | `flutter test` (na raiz de cada package) |
| Análise | `dart analyze` — sem issues antes de qualquer PR |
| Web build | `cd apps/web && flutter build web` |

## O que já funciona neste esqueleto

- Login → 1 institution = home direto; N = tela de escolha com padrão local pré-selecionado (decisões 3, 15)
- Shell web: menu vertical de módulos → interfaces → frame, 100% via `GET /api/core/menus`, acionado por clique (decisões 21, 22)
- i18n pt/en com easy_localization (decisão 13) — sincronização com `/api/core/preferences` na próxima etapa
- Fábrica de cadastros: `RegisterSearchPage<T>` / `RegisterFormPage` + `RegisterField` (decisão 20)
- Responsividade: `Responsive` 850/1100 + arquivos content por breakpoint (decisão 5)

## Próximas etapas da Fase 1

1. Tema por institution na UI (`GET /api/core/theme` → ThemeData dinâmico — decisão 16)
2. Sincronizar locale com `/api/core/preferences` (decisão 14)
3. Cadastros do módulo Super (privilégios, interfaces, clientes) e Sistema (estabelecimento, usuários, módulos) usando a fábrica
4. Integration tests E2E (fluxo completo de login)
