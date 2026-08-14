<p align="center">
  <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell">
  <img src="https://img.shields.io/badge/Licença-MIT-22c55e?style=for-the-badge" alt="MIT">
  <img src="https://img.shields.io/badge/AV%20safe%20path-Executar.bat-0d9488?style=for-the-badge" alt="AV safe">
</p>

<h1 align="center">◈ PC Otimizador Pro</h1>

<p align="center">
  <b>Limpeza e otimização segura para Windows</b><br>
  Menu no terminal · presets de 1 clique · GUI opcional<br>
  Feito para passar a amigos — sem apagar arquivos pessoais.
</p>

<p align="center">
  <a href="#-comece-em-30-segundos"><b>Começar</b></a> ·
  <a href="#-o-que-ele-faz">O que faz</a> ·
  <a href="#-menu-hierarquia">Menu</a> ·
  <a href="#-segurança">Segurança</a> ·
  <a href="#-antivirus"><b>Antivirus</b></a>
</p>

---

## ⚡ Comece em 30 segundos

1. **[Download ZIP](https://github.com/leonardolauriquer/PC-Otimizador/archive/refs/heads/main.zip)** (ou `git clone`)
2. Extraia a pasta
3. Clique duas vezes em **`Executar.bat`**
4. Aceite o UAC (Administrador)
5. Digite **`1`** → **Limpeza Segura** → **`E`** para executar

> **Regra de ouro:** se o antivírus reclamar de `.exe`, ignore o exe e use só o `.bat`.

---

## ✨ Por que este projeto?

| | |
|---|---|
| 🛡️ **Seguro por padrão** | Não toca em Documentos, Fotos, Downloads, Desktop, favoritos ou senhas |
| 🎯 **Impossível se perder** | Hierarquia clara: presets → personalizar → executar |
| 🧩 **Tudo opcional** | Cada item pode ser marcado / desmarcado |
| 🖥️ **Dois modos** | Terminal (recomendado) ou interface gráfica |
| 📦 **Sem instalador** | Portátil — só extrair e rodar |

---

## 🧰 O que ele faz

### Limpeza
- Temporários (usuário + Windows)
- Lixeira
- Cache do Windows Update e Delivery Optimization
- Miniaturas / ícones, logs, WER e dumps
- `cleanmgr` + DISM Component Cleanup
- Caches opcionais: navegadores, GPU/shaders, Discord/Steam/Teams/Spotify, Store
- Avançado: Prefetch, `Windows.old` / `$Windows.~BT`

### Performance
- TRIM / otimizar unidades (SSD)
- Storage Sense (**sem** limpar Downloads)
- Reduzir dicas / telemetria básica
- Planos de energia, efeitos visuais
- Apps em 2º plano, Widgets, busca web no Iniciar
- Game Bar / DVR off · Modo de Jogo on

### Internet
- Flush DNS / ARP / NetBIOS
- Tweaks TCP leves
- Renovar IP, DNS Cloudflare ou Google
- Anti-Nagle (latência)
- Reset Winsock / TCP-IP (só se a rede estiver ruim)

### Manutenção
- Ponto de restauração
- `SFC /scannow`
- `DISM /RestoreHealth`
- Varredura (medir espaço **sem apagar**)

---

## 🗺️ Menu (hierarquia)

```text
Executar.bat
│
├─ 1. Limpeza Segura ★          ← use este se não souber o que escolher
├─ 2. Turbo / Gamer
├─ 3. Reparar Internet
├─ 4. Preset Completo
│
├─ 5. Personalizar
│   ├─ Limpeza        → marca [X] item a item
│   ├─ Performance
│   ├─ Internet
│   ├─ Manutenção
│   └─ Executar selecionadas
│
├─ 6. Só varrer                 ← só mede espaço
├─ 7. Interface gráfica         ← janela moderna
└─ 0. Sair
```

**Atalhos no personalizar:** número = marcar/desmarcar · `A` = todas · `L` = limpar · `E` = executar · `V` = voltar

---

## 📁 Arquivos do projeto

| Arquivo | Função |
|---------|--------|
| [`Executar.bat`](Executar.bat) | **Entrada principal** — comece por aqui |
| [`PC-Otimizador-CLI.ps1`](PC-Otimizador-CLI.ps1) | Menus no terminal |
| [`Engine.ps1`](Engine.ps1) | Motor compartilhado (limpeza/otimização) |
| [`PC-Otimizador.ps1`](PC-Otimizador.ps1) | Interface gráfica (opção 7) |
| [`Launcher.cs`](Launcher.cs) + [`Compilar-EXE.ps1`](Compilar-EXE.ps1) | Launcher C# opcional (sem ps2exe) |
| [`LEIA-ME.txt`](LEIA-ME.txt) | Instruções curtas para leigos |

Para funcionar, mantenha na **mesma pasta**:
`Executar.bat` + `PC-Otimizador-CLI.ps1` + `Engine.ps1`

---

## 🛡️ Segurança

- ✅ Não formata disco  
- ✅ Não desinstala programas  
- ✅ Não desativa Windows Defender  
- ✅ Não instala adware / mineradores  
- ✅ Preset seguro cria **ponto de restauração** quando possível  
- ⚠️ Opções em amarelo = atenção · vermelho = avançado  

Use por sua conta e risco. Em PC de empresa, peça autorização do TI.

---

## 🦠 Antivirus

Ferramentas tipo **ps2exe** (script → `.exe`) geram falso positivo clássico:

`Gen:Variant.Adware.MSILHeracles.*` (IObit / Bitdefender)

**Por isso o caminho oficial é o `.bat`.**

| Situação | O que fazer |
|----------|-------------|
| Quer zero alerta | Use só `Executar.bat` |
| Gerou launcher C# e alertou | Lista branca / exclusões |
| Achou `.bak` / `*ps2exe*` antigo | Apague — é lixo de build |

```powershell
# Launcher opcional (C# limpo, sem ps2exe)
powershell -ExecutionPolicy Bypass -File .\Compilar-EXE.ps1
```

---

## 🔧 Requisitos

- Windows **10** ou **11**
- PowerShell **5.1+**
- Preferência: executar como **Administrador**

```powershell
git clone https://github.com/leonardolauriquer/PC-Otimizador.git
cd PC-Otimizador
.\Executar.bat
```

---

## 🛣️ Roadmap (próximos passos)

- [ ] Estimativa de espaço **antes** de limpar (por item)
- [ ] Log exportável da sessão (`.txt`)
- [ ] Perfil **Notebook** (equilibrado + bateria)
- [ ] Agendar limpeza semanal (Agendador de Tarefas)
- [ ] GUI 100% nativa em C# (menos atrito com AV)
- [ ] Assinatura Authenticode do launcher (opcional / pago)
- [ ] Tema claro na GUI
- [ ] Idioma EN

Sugestões? Abra uma [Issue](https://github.com/leonardolauriquer/PC-Otimizador/issues).

---

## 📜 Licença

[MIT](LICENSE) — use, compartilhe e adapte livremente.

---

<p align="center">
  Feito para ajudar amigos a deixar o PC mais leve — sem medo de perder arquivos.
</p>
