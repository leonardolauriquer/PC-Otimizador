# Core compartilhado

Este diretório define a **política e os presets** comuns entre plataformas.

| Arquivo | Uso |
|---------|-----|
| `presets.json` | Nomes de presets, ações lógicas, pastas intocáveis |
| `SECURITY.md` | Regras de segurança multiplataforma |

Cada OS tem um **adapter** (`Engine.ps1`, `linux/*.sh`, `macos/*.sh`, …) que implementa as ações com APIs nativas.

Não misture scripts Windows e Unix no mesmo executável.
