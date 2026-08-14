<p align="center">
  <img src="docs/readme-hero.png" alt="PC Otimizador Pro" width="900">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/v5-Live%20progress%20%7C%20Cancel%20%7C%20Health-0d9488?style=for-the-badge" alt="v5">
  <img src="https://img.shields.io/badge/Licença-MIT-22c55e?style=for-the-badge" alt="MIT">
</p>

<h1 align="center">◈ PC Otimizador Pro</h1>

<p align="center">
  <b>Limpeza e otimização segura para Windows</b><br>
  Progresso ao vivo · Cancelar · Health Score · Whitelist · SSD/HDD · Dry-run · Logs · Agenda<br>
  <i>Não apaga Documentos, Fotos, Downloads, Desktop, favoritos ou senhas.</i>
</p>

---

## ⚡ Comece em 30 segundos

1. **[Download ZIP](https://github.com/leonardolauriquer/PC-Otimizador/archive/refs/heads/main.zip)** (ou Releases)
2. Extraia → clique em **`Executar.bat`** → UAC
3. Digite **`1`** (Limpeza Segura) → **`E`**  
   Ou **`D`** = dry-run · **`H`** = Health Score

> Caminho anti-AV: **`Executar.bat`**. O `.exe` é GUI C# nativa (sem ps2exe).

---

## ✨ Novidades v5

| Recurso | Descrição |
|---------|-----------|
| **Progresso ao vivo** | Barra + etapa atual na GUI C# (`##PROGRESS##`) |
| **Cancelar** | Botão Cancelar / flag em `%TEMP%` |
| **Antes / Depois** | Disco + RAM no painel de resultado |
| **Health Score** | 0–100 (disco, RAM, lixo recuperável) |
| **Whitelist** | Pastas pessoais sempre protegidas + extras |
| **SSD / HDD** | Detecta mídia; avisa Prefetch em SSD |
| **Bloatware** | Lista AppX + confirmação (nunca automático) |
| **Release ZIP** | GitHub Actions em tags `v*` |
| **EN/PT** | Idioma no menu |

---

## 🗺️ Menu (`Executar.bat`)

```text
1 Limpeza Segura ★   2 Gamer   3 Internet   4 Completo   5 Notebook
6 Personalizar       7 Varrer+Health   8 Dry-run   9 Agendar
R Remover agenda     H Health   W Whitelist   B Bloat   G GUI   0 Sair
```

---

## 📁 Arquivos

| Arquivo | Função |
|---------|--------|
| `Executar.bat` | Entrada principal |
| `Engine.ps1` | Motor v5 |
| `PC-Otimizador-CLI.ps1` | Menus terminal |
| `GuiNative.cs` → `PC-Otimizador.exe` | GUI com progresso/cancel |
| `PC-Otimizador.ps1` | GUI PowerShell alternativa |
| `Tests/Engine.Tests.ps1` | Testes |
| `.github/workflows/release.yml` | ZIP de release |

**Whitelist:** `Documentos\PC-Otimizador-Logs\whitelist.txt`  
**Logs:** `Documentos\PC-Otimizador-Logs\sessao-*.txt`

---

## 🛡️ Segurança

- Whitelist automática: Documentos, Fotos, Vídeos, Desktop, Downloads  
- Dry-run e estimativa antes de limpar  
- Bloat só com confirmação interativa  
- Assinatura Authenticode: opcional (certificado pago) — use `.bat` se o AV reclamar  

---

## 🧪 Testes / Build / Release

```powershell
powershell -ExecutionPolicy Bypass -File .\Tests\Engine.Tests.ps1
powershell -ExecutionPolicy Bypass -File .\Compilar-EXE.ps1
```

```bash
git tag v5.0.0
git push origin v5.0.0
# Actions gera PC-Otimizador-Windows.zip na Release
```

Ou rode o workflow **Release** manualmente no GitHub Actions.

---

## 📜 Licença

[MIT](LICENSE)
