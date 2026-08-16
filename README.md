<p align="center">
  <img src="docs/readme-hero.png" alt="PC Otimizador Pro" width="900">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/Linux-Bash-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Linux">
  <img src="https://img.shields.io/badge/macOS-Bash-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS">
  <img src="https://img.shields.io/badge/Android-Termux-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android">
  <img src="https://img.shields.io/badge/v5.6.0-Device%20Inspector-0d9488?style=for-the-badge" alt="v5.6.0">
  <img src="https://img.shields.io/badge/Licença-MIT-22c55e?style=for-the-badge" alt="MIT">
</p>

<h1 align="center">◈ PC Otimizador Pro</h1>

<p align="center">
  <b>Limpeza e otimização segura — monorepo multiplataforma</b><br>
  Windows · Linux · macOS · Android (Termux) · iOS (só documentação honesta)<br>
  <i>Não percorre pastas pessoais; a Lixeira e ações avançadas exigem confirmação explícita.</i>
</p>

---

## Arquitetura

Um **core** de política + um **adapter por SO**. Não existe um único `.bat`/`.ps1` para todos os sistemas.

```text
core/          presets + SECURITY (compartilhado)
Engine.ps1     Windows (maduro)
linux/         Bash CLI
macos/         Bash CLI
android/       Termux (sandbox honesto)
ios/           README — sem limpador de sistema
```

Detalhes: [`core/README.md`](core/README.md) · [`core/SECURITY.md`](core/SECURITY.md)

---

## Comece rápido

### Windows (recomendado)

1. **[Baixe a release mais recente](https://github.com/leonardolauriquer/PC-Otimizador/releases/latest)** (ZIP + `SHA256SUMS.txt`)
2. Extraia → **`Executar.bat`** → UAC
3. Digite **`1`** (Limpeza Segura) → **`E`**  
   Ou **`8`** = dry-run no menu `.bat` · **`H`** = Health Score

> Anti-AV: use **`Executar.bat`**. O `.exe` é GUI C# nativa (sem ps2exe).

### Linux

```bash
cd linux && chmod +x pc-otimizador.sh && ./pc-otimizador.sh
# ./pc-otimizador.sh --preset safe --yes
```

### macOS

```bash
cd macos && chmod +x pc-otimizador.sh && ./pc-otimizador.sh
# ./pc-otimizador.sh --preset safe --yes
```

### Android (Termux)

```bash
cd android && chmod +x termux-pc-otimizador.sh && ./termux-pc-otimizador.sh
```

Só limpa o ambiente Termux — **não** o telefone inteiro. Ver [`android/README.md`](android/README.md).

### iOS

Sem otimizador de sistema legítimo. Ver [`ios/README.md`](ios/README.md).

---

## Novidades v5.6.0

| Recurso | Descrição |
|---------|-----------|
| **Dashboard visual redesenhado** | GUI nativa com tema neon, sidebar com ícones, cards responsivos, progresso com glow e métricas antes/depois |
| **Layout responsivo corrigido** | Coordenadas relativas por página, colunas com largura estável, título medido por fonte e páginas internas com fluxo/scroll |
| **Inspetor do dispositivo** | Nova aba com CPU, GPU, RAM por módulo, placa-mãe, BIOS, discos, rede, frequências, carga e temperaturas expostas pelo Windows |
| **Navegação funcional** | As oito entradas da barra lateral abrem páginas próprias; Configurações não retorna mais ao Início e páginas secundárias não recebem o dashboard por cima |
| **Ícones oficiais do Windows** | Interface usa **Segoe Fluent Icons**, sistema recomendado pela Microsoft no Windows 11, com fallback para Segoe MDL2 Assets no Windows 10 |
| **Idioma consistente** | Português e inglês são aplicados imediatamente ao título, navegação, cards, modo de simulação, saúde, confirmações, resultados e orientações |
| **Modo de simulação reposicionado** | O controle fica em uma linha separada dos botões minimizar/maximizar/fechar e possui teste automático contra sobreposição |
| **Acabamento visual do dashboard** | Subtítulo sem clipping, métricas com ícones dedicados, painel de status compacto e botão PARAR oculto até existir uma execução |
| **Allowlist de limpeza** | Raízes, ancestrais, pastas pessoais e reparse points são recusados antes de qualquer exclusão |
| **Risco aplicado ponta a ponta** | DNS, energia, rede, Lixeira, CleanMgr, Prefetch e upgrade exigem confirmação explícita |
| **Auto-update fail-closed** | ZIP protegido contra traversal, staging privado, arquivos obrigatórios e versão do pacote validados |
| **SHA256 obrigatório** | Recusa releases sem `SHA256SUMS.txt` ou com hash ausente/inválido |
| **Presets seguros revisados** | A Limpeza Segura não esvazia a Lixeira, não executa CleanMgr e não força o fechamento de aplicativos |
| **Adapters Unix mais restritos** | Linux/macOS limpam apenas temporários antigos do usuário; Termux permanece no sandbox do próprio app |
| **CI e auditoria** | Testes de engine, testes estáticos, sintaxe Bash, JSON e pacote de release são verificados no CI |

Os ícones seguem a documentação oficial [Segoe Fluent Icons](https://learn.microsoft.com/windows/apps/design/iconography/segoe-fluent-icons-font) e os princípios de [iconografia do Windows](https://learn.microsoft.com/windows/apps/design/signature-experiences/iconography). A fonte já faz parte do Windows; nenhum pacote de ícones de procedência incerta é distribuído.

> O executável distribuído não possui assinatura Authenticode. Se o SmartScreen alertar, use `Executar.bat` ou verifique o hash da release antes de executar.

### Política de risco

- **Seguro:** caches e temporários regeneráveis dentro da allowlist.
- **Cautela:** ajustes reversíveis de rede, aplicativos e manutenção do sistema.
- **Alto risco:** alterações de DNS/energia/IP, Winsock/TCP-IP, Prefetch, CleanMgr, Lixeira, bloatware e upgrade. Esses itens nunca são executados silenciosamente.
- **Dry-run:** use a opção `8` ou `-DryRun` para estimar e revisar sem apagar nada.

---

## Novidades v5.4

| Recurso | Descrição |
|---------|-----------|
| **GUI = foto do README** | Sidebar + cards + % grande + Health + antes/depois |
| **Navegação segura** | Menu lateral não dispara limpeza sozinho |
| **Ferramentas / Configurações** | Telas dedicadas no dashboard |

---

## Novidades v5.3

| Recurso | Descrição |
|---------|-----------|
| **core/presets.json** | Fonte da verdade (Windows + Bash via `load_preset.py`) |
| **Whitelist boundary** | Não confunde `Documents` com `DocumentsBackup` |
| **Alto risco** | DNS/energia/IP exigem confirmação (`-AllowHighRisk` após UI) |
| **GUI** | Risk badges, DPI parcial, tema escuro (dashboard) |
| **Release** | Testes no CI + `SHA256SUMS.txt` + assert de arquivos |
| **Progresso ao vivo** | Barra + etapa na GUI C# (`##PROGRESS##`) |
| **Health Score** | 0–100 (disco, RAM, lixo) |
| **Linux / macOS / Termux** | Adapters Bash alinhados ao core |

---

## Novidades v5 / v5.2

| Recurso | Descrição |
|---------|-----------|
| **Cancelar** | Botão / flag em `%TEMP%` |
| **SSD / HDD** | Detecta mídia; avisa Prefetch em SSD |
| **Bloatware** | AppX só com confirmação |
| **Release ZIP** | Actions em tags `v*` |

---

## Menu Windows (`Executar.bat`)

```text
1 Limpeza Segura ★   2 Gamer   3 Internet   4 Completo   5 Notebook
6 Personalizar       7 Varrer+Health   8 Dry-run   9 Agendar
R Remover agenda     H Health   W Whitelist   B Bloat   G GUI   0 Sair
```

---

## Arquivos

| Caminho | Função |
|---------|--------|
| `Executar.bat` | Entrada Windows |
| `Engine.ps1` | Motor Windows v5 |
| `PC-Otimizador-CLI.ps1` | Menus terminal |
| `GuiNative.cs` → `PC-Otimizador.exe` | GUI progresso/cancel |
| `core/` | Presets + política |
| `linux/pc-otimizador.sh` | CLI Linux |
| `macos/pc-otimizador.sh` | CLI macOS |
| `android/termux-pc-otimizador.sh` | Termux |
| `ios/README.md` | Escopo iOS |
| `Tests/Engine.Tests.ps1` | Testes Windows |
| `Tests/Static.Tests.ps1` | Testes estáticos de segurança e regressão |
| `Tests/Gui.Layout.Tests.ps1` | Contrato de layout, navegação, páginas e troca de idioma em três resoluções |

**Whitelist (Windows):** `Documentos\PC-Otimizador-Logs\whitelist.txt`  
**Logs (Windows):** `Documentos\PC-Otimizador-Logs\sessao-*.txt`

---

## Segurança

- Allowlist de caches; raízes, ancestrais e reparse points são recusados
- Boundary-safe (prefixo com separador de pasta)  
- Dry-run e estimativa antes de limpar  
- DNS / plano de energia / renovar IP / Lixeira / CleanMgr = confirmação explícita
- Mobile: só sandbox permitido (Termux / docs iOS)  
- Release com testes + SHA256 obrigatório; Authenticode recomendado para distribuição

---

## Testes / Build / Release

```powershell
powershell -ExecutionPolicy Bypass -File .\Tests\Engine.Tests.ps1
powershell -ExecutionPolicy Bypass -File .\Tests\Static.Tests.ps1
powershell -ExecutionPolicy Bypass -File .\Tests\Gui.Layout.Tests.ps1
powershell -ExecutionPolicy Bypass -File .\Compilar-EXE.ps1
```

```bash
git tag v5.6.0
git push origin v5.6.0
# Actions: testes Windows + smoke Bash → ZIP + SHA256SUMS.txt
```

---

## Licença

[MIT](LICENSE)
