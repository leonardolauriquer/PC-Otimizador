<p align="center">
  <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell">
  <img src="https://img.shields.io/badge/Licença-MIT-22c55e?style=for-the-badge" alt="MIT">
  <img src="https://img.shields.io/badge/v4-Dry--run%20%7C%20Estimates%20%7C%20Logs-0d9488?style=for-the-badge" alt="v4">
</p>

<h1 align="center">◈ PC Otimizador Pro</h1>

<p align="center">
  <b>Limpeza e otimização segura para Windows</b><br>
  Terminal · GUI C# · presets · dry-run · estimativas · logs · agenda semanal<br>
  <i>Não apaga Documentos, Fotos, Downloads, Desktop, favoritos ou senhas.</i>
</p>

<p align="center">
  <a href="#-comece-em-30-segundos"><b>Começar</b></a> ·
  <a href="#-novidades-v4">Novidades v4</a> ·
  <a href="#-menu">Menu</a> ·
  <a href="#-segurança">Segurança</a> ·
  <a href="#-antivirus">Antivirus</a>
</p>

---

## ⚡ Comece em 30 segundos

1. **[Download ZIP](https://github.com/leonardolauriquer/PC-Otimizador/archive/refs/heads/main.zip)**
2. Extraia a pasta
3. Clique em **`Executar.bat`** → aceite o UAC
4. Digite **`1`** (Limpeza Segura) → **`E`** executar  
   (ou **`D`** para dry-run / **`M`** só estimar MB)

> Preferência anti-AV: use o **`.bat`**. O `.exe` é GUI C# limpa (não é ps2exe).

---

## ✨ Novidades v4

| Recurso | Descrição |
|---------|-----------|
| **Estimativa por item** | Mostra MB recuperáveis antes de limpar |
| **Dry-run** | Simula tudo sem apagar |
| **Log de sessão** | Salvo em `Documentos\PC-Otimizador-Logs\` |
| **Perfil Notebook** | Equilibrado, sem Alto Desempenho |
| **Agenda semanal** | Domingo 10:00 (Agendador de Tarefas) |
| **GUI C# nativa** | `PC-Otimizador.exe` (WinForms) |
| **PT / EN** | Alternância básica de idioma |
| **Tema claro/escuro** | Na interface gráfica |
| **Testes** | `Tests\Engine.Tests.ps1` |

---

## 🗺️ Menu

```text
Executar.bat
├─ 1. Limpeza Segura ★
├─ 2. Turbo / Gamer
├─ 3. Reparar Internet
├─ 4. Preset Completo
├─ 5. Notebook (bateria)
├─ 6. Personalizar          → Limpeza | Perf | Net | Manutenção
├─ 7. Varrer + estimar MB
├─ 8. Dry-run Limpeza Segura
├─ 9. Agendar limpeza semanal
├─ R. Remover agendamento
├─ G. Interface gráfica
└─ 0. Sair
```

Nos presets: **`E`** executa · **`D`** dry-run · **`M`** só estima · **`V`** volta

---

## 📁 Arquivos

| Arquivo | Função |
|---------|--------|
| `Executar.bat` | Entrada principal |
| `Engine.ps1` | Motor (limpeza, estimativas, logs, agenda) |
| `PC-Otimizador-CLI.ps1` | Menus no terminal |
| `PC-Otimizador.ps1` | GUI PowerShell (alternativa) |
| `GuiNative.cs` | GUI C# (fonte) |
| `PC-Otimizador.exe` | GUI compilada (`Compilar-EXE.ps1`) |
| `Tests/Engine.Tests.ps1` | Testes do motor |

**Obrigatórios juntos:** `Executar.bat` + `Engine.ps1` + `PC-Otimizador-CLI.ps1`  
**Para o .exe:** os três acima + `PC-Otimizador.exe`

---

## 🧰 O que limpa / otimiza

**Limpeza:** temp, lixeira, Update, Delivery Opt, thumbs, WER/dumps, logs, cleanmgr, DISM cleanup, caches (browser/GPU/apps/Store), Prefetch e Windows.old (avançado).

**Performance:** TRIM, Storage Sense (sem Downloads), telemetria/dicas, energia, efeitos, apps 2º plano, Widgets, Game Bar, Modo de Jogo.

**Internet:** DNS/ARP/NetBIOS, TCP tweaks, renovar IP, Cloudflare/Google DNS, Nagle, Winsock/TCP-IP.

**Manutenção:** ponto de restauração, SFC, DISM RestoreHealth.

---

## 🛡️ Segurança

- Não formata, não remove programas, não desativa Defender  
- Preset seguro tenta criar ponto de restauração  
- Amarelo = atenção · vermelho = avançado  
- Dry-run disponível antes de qualquer limpeza real  

---

## 🦠 Antivirus

`ps2exe` → falso positivo `MSILHeracles` (IObit/Bitdefender).  
Este projeto **não usa ps2exe**. O `.exe` é C# compilado com `csc`.

Ainda assim, `.exe` unsigned pode alertar. Solução: **`Executar.bat`**.

Assinatura Authenticode (certificado pago) é o único jeito “profissional” de zerar alertas em escala.

---

## 🧪 Testes

```powershell
powershell -ExecutionPolicy Bypass -File .\Tests\Engine.Tests.ps1
```

## 🔧 Compilar GUI

```powershell
powershell -ExecutionPolicy Bypass -File .\Compilar-EXE.ps1
```

## 📦 Clone

```powershell
git clone https://github.com/leonardolauriquer/PC-Otimizador.git
cd PC-Otimizador
.\Executar.bat
```

---

## 📜 Licença

[MIT](LICENSE)

<p align="center">Feito para ajudar amigos — sem medo de perder arquivos.</p>
