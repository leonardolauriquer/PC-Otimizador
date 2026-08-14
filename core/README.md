# Core compartilhado

Este diretório é a **fonte da verdade** dos presets e da política de risco.

| Arquivo | Uso |
|---------|-----|
| `presets.json` | Presets por plataforma (`windows` / `linux` / `macos` / `android_termux`) + `risk_actions` |
| `load_preset.py` | Helper para adapters Bash (`python3 core/load_preset.py linux safe`) |
| `SECURITY.md` | Regras de segurança multiplataforma |

- **Windows:** `Engine.ps1` → `Get-PresetIds` / `Get-HighRiskActionIds` leem o JSON.
- **Linux/macOS:** `preset_ids()` chama `load_preset.py` com fallback embutido.
- **iOS:** sem limpeza de sistema (ver `ios/README.md`).

Não misture scripts Windows e Unix no mesmo executável.
