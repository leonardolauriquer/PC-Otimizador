# PC Otimizador Pro

Limpeza e otimização segura para **Windows 10/11**.  
Feito para passar a amigos: menu no terminal, presets de 1 clique e interface gráfica opcional.

> **Não apaga** Documentos, Fotos, Downloads, Desktop, favoritos nem senhas.

## Comece aqui (recomendado)

1. Baixe o ZIP do repositório (ou clone)
2. Extraia a pasta
3. Clique duas vezes em **`Executar.bat`**
4. Aceite o UAC (Administrador)
5. Escolha **`1` — Limpeza Segura**

## Hierarquia do menu

```
Executar.bat
├─ 1. Limpeza Segura ★          (recomendado)
├─ 2. Turbo / Gamer
├─ 3. Reparar Internet
├─ 4. Preset Completo
├─ 5. Personalizar
│    ├─ Limpeza
│    ├─ Performance
│    ├─ Internet
│    └─ Manutenção
├─ 6. Só varrer (não apaga nada)
├─ 7. Interface gráfica
└─ 0. Sair
```

## Arquivos

| Arquivo | Função |
|--------|--------|
| `Executar.bat` | Entrada principal (use este) |
| `PC-Otimizador-CLI.ps1` | Menus no terminal |
| `Engine.ps1` | Motor de limpeza/otimização |
| `PC-Otimizador.ps1` | Interface gráfica (opção 7) |
| `Launcher.cs` + `Compilar-EXE.ps1` | Launcher C# opcional (sem ps2exe) |

## O que faz

- Temporários, Lixeira, cache de Update, Delivery Optimization  
- Miniaturas, logs, WER/dumps, cleanmgr, DISM cleanup  
- TRIM/SSD, Storage Sense, dicas/telemetria leve  
- DNS/ARP/NetBIOS, tweaks TCP, DNS Cloudflare/Google (opcional)  
- Game Bar, Modo de Jogo, apps em 2º plano (opcional)  
- Ponto de restauração, SFC, DISM RestoreHealth (opcional)

## Antivirus / falso positivo

Exes gerados com **ps2exe** disparam heurística `MSILHeracles` (IObit/Bitdefender).  
Por isso o caminho oficial é **`Executar.bat` + scripts**.

Se gerar o `.exe` launcher C# e o antivírus reclamar: lista branca ou use só o `.bat`.

## Compilar launcher (opcional)

```powershell
powershell -ExecutionPolicy Bypass -File .\Compilar-EXE.ps1
```

## Requisitos

- Windows 10 ou 11  
- PowerShell 5.1+  
- Preferencialmente Executar como Administrador  

## Aviso

Use por sua conta e risco. Em PCs corporativos, peça autorização do TI.  
Sempre há opção de criar ponto de restauração antes.

## Licença

MIT — use, compartilhe e adapte livremente.
