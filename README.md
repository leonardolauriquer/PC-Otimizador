<p align="center">
  <img src="docs/readme-hero.png" alt="PC Otimizador Pro" width="900">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/Linux-Bash-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Linux">
  <img src="https://img.shields.io/badge/macOS-Bash-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS">
  <img src="https://img.shields.io/badge/Android-Termux-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android">
  <img src="https://img.shields.io/badge/v5.9.0-Consent%20%26%20Control-0d9488?style=for-the-badge" alt="v5.9.0">
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

### Compatibilidade e nível de suporte

| Plataforma | Suporte | Estratégia |
|---|---|---|
| Windows 11 / Windows 10 | Principal | GUI nativa + PowerShell 5.1; detecção de build, CIM/WMI, cmdlets e executáveis do sistema |
| Windows Server com Desktop Experience | Compatível por capacidade | CLI recomendada; recursos ausentes são identificados e não são declarados como concluídos |
| Linux | Módulo próprio | Bash; detecta apt, dnf, pacman e zypper, sem aplicar comandos Windows |
| macOS | Módulo próprio | Bash e ferramentas nativas; Homebrew é opcional |
| Android / Termux | Escopo limitado | Atua somente dentro do sandbox do Termux; não promete limpeza global do Android |
| iOS / iPadOS | Não suportado | O sistema não concede acesso necessário a um otimizador desse tipo |

“Compatível” não significa executar a mesma receita em todo computador. O motor seleciona somente capacidades presentes, tenta alternativas previamente aprovadas e verifica o resultado. Uma ação bloqueada por política, edição do Windows, antivírus, hardware ou permissão é reportada como indisponível ou falha — nunca como sucesso.

### Política de resiliência

1. Detectar sistema, build, arquitetura, privilégios e comandos disponíveis.
2. Validar pré-condições antes de alterar qualquer estado.
3. Executar o método preferencial.
4. Em falha recuperável, tentar um método alternativo seguro.
5. Confirmar código de saída e pós-condição observável.
6. Registrar cada tentativa, preservando a causa original.
7. Falhar honestamente quando não houver método confiável.

### Windows (recomendado)

1. **[Baixe a release mais recente](https://github.com/leonardolauriquer/PC-Otimizador/releases/latest)** (ZIP + `SHA256SUMS.txt`)
2. Extraia → **`Executar.bat`** → UAC
3. Digite **`1`** (Limpeza Segura) e confirme com **`CONCORDO`**  
   Na GUI: revise a lista, **Recusar** ou **Concordo — executar** · **`H`** = Health Score

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

## Novidades v5.9.0

- **Consentimento explícito:** a GUI lista cada ação com SAFE / ATENÇÃO / RISCO e estimativa de tamanho; **Recusar** cancela e **Concordo — executar** só libera o que estiver marcado.
- **Sem simulação na GUI:** dry-run permanece na CLI / `Executar.bat` (`8`); a interface nativa executa somente o que você autorizou.
- **Última seleção lembrada** por perfil, com histórico de saúde no painel.
- **Desfazer ajustes:** snapshot de DNS, plano de energia, Nagle e registro conhecidos; o restore ignora caminhos fora da allowlist.
- **Agenda semanal** com dia, hora e as ações autorizadas (não mais um lote SAFE fixo).
- **Inicialização do Windows:** habilitar/desabilitar entradas HKCU/HKLM Run, com validação de hive, nome e comando.
- **Assinatura Authenticode** quando o certificado existir no build; o SmartScreen continua exigindo um certificado real — não é possível forjar confiança.

### Incluído desde v5.8.0

- **Contrato por ação:** cada etapa emite `SUCCESS`, `FAILED`, `SKIPPED` ou `BLOCKED`, método utilizado e causa.
- **Timeouts:** processos externos possuem limite e são encerrados com segurança quando travam; a GUI possui limite global de duas horas.
- **Concorrência:** mutex global no Windows e lock com recuperação de estado obsoleto no Linux, macOS e Termux.
- **Rollback transacional:** alterações de Registro, DNS e plano de energia retornam ao estado anterior quando a ação falha.
- **Atualização recuperável:** backup da versão anterior, manifesto interno, hashes pós-cópia, teste de inicialização e rollback automático.
- **Assinatura pronta para produção:** CI assina EXE e scripts e ativa fiscalização no atualizador quando os secrets do certificado são configurados.
- **Diagnóstico opt-in:** desligado por padrão, sem usuário, caminho, IP, hostname, serial ou ID do dispositivo; consentimento controlável nas Configurações.
- **Matriz real de CI:** Windows Server 2022/runner atual, Ubuntu 22.04/24.04 e macOS 14/15, além do workflow para laboratório físico.
- **Testes de falha:** timeout, fallback, lock concorrente, idempotência, rollback, telemetria privada, manifesto adulterado e assinatura obrigatória.
- **Matriz por recurso:** [`core/compatibility.json`](core/compatibility.json) documenta método, privilégio, reversibilidade e verificação de cada ação.

### Incluído desde v5.7.0

- **Detecção de capacidades:** registra versão/build do Windows, PowerShell, arquitetura, elevação e ferramentas realmente disponíveis.
- **Fallback controlado:** quando o método moderno falha, tenta uma alternativa compatível e registra qual método funcionou.
- **Sucesso verificável:** comandos externos validam código de saída; planos de energia e alterações de Registro confirmam o estado final.
- **Sem falso positivo:** se todas as alternativas falharem, a ação e o lote terminam como falha e o log explica cada tentativa.
- **Compatibilidade legada segura:** inventário por CIM com fallback para WMI e, por último, APIs .NET sem inventar métricas ausentes.
- **Adaptação por versão:** opções TCP removidas de versões novas são ignoradas individualmente com aviso; a configuração suportada continua.

### Incluído desde v5.6.1

- **Controle de simulação redesenhado:** componente retangular integrado ao visual dos painéis, com barra de estado, chave liga/desliga e realce ciano no hover, foco e estado ativo.
- **Botões coerentes:** seletores PT/EN, ações dos cartões e botões das páginas agora compartilham borda, cantos, foco e hover do mesmo sistema visual.
- **Acessibilidade:** a simulação voltou à ordem de tabulação e todos os controles personalizados exibem foco perceptível.

### Incluído desde v5.6.0

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
| `core/` | Presets, política e matriz de compatibilidade por ação |
| `linux/pc-otimizador.sh` | CLI Linux |
| `macos/pc-otimizador.sh` | CLI macOS |
| `android/termux-pc-otimizador.sh` | Termux |
| `ios/README.md` | Escopo iOS |
| `Tests/Engine.Tests.ps1` | Testes Windows |
| `Tests/Static.Tests.ps1` | Testes estáticos de segurança e regressão |
| `Tests/Gui.Layout.Tests.ps1` | Contrato de layout, navegação, páginas e troca de idioma em três resoluções |
| `Tests/Reliability.Tests.ps1` | Timeout, fallback, concorrência, idempotência, rollback e privacidade |
| `Tests/Updater.Tests.ps1` | Manifesto, adulteração, assinatura e rollback do atualizador |
| `Tests/Hardware.Contract.ps1` | Relatório de cobertura de hardware sem identificadores pessoais |

**Whitelist (Windows):** `Documentos\PC-Otimizador-Logs\whitelist.txt`  
**Logs (Windows):** `Documentos\PC-Otimizador-Logs\sessao-*.txt`

---

## Segurança

- Allowlist de caches; raízes, ancestrais e reparse points são recusados
- Boundary-safe (prefixo com separador de pasta)  
- Dry-run e estimativa antes de limpar  
- DNS / plano de energia / renovar IP / Lixeira / CleanMgr = confirmação explícita
- Mobile: só sandbox permitido (Termux / docs iOS)  
- Release com testes, SHA256, manifesto por arquivo e proveniência assinada pelo GitHub
- Authenticode é aplicado e exigido automaticamente quando o certificado de produção está configurado

### Diagnóstico opcional

O diagnóstico permanece **desligado por padrão**. Pode ser habilitado na aba Configurações ou pela CLI:

```powershell
# Apenas arquivo local; não transmite nada
.\PC-Otimizador-CLI.ps1 -Mode telemetryon

# Transmissão somente após consentimento explícito e somente para HTTPS
.\PC-Otimizador-CLI.ps1 -Mode telemetryon -TelemetryEndpoint https://seu-endpoint.example/events

.\PC-Otimizador-CLI.ps1 -Mode telemetrystatus
.\PC-Otimizador-CLI.ps1 -Mode telemetryoff
```

Campos permitidos: versão do aplicativo, versão/build do sistema, PowerShell, ação, status, duração e categoria genérica da falha. Não são coletados usuário, hostname, caminhos, nomes de arquivos, IP, serial, localização ou identificadores de hardware.

### Assinatura de produção

Configure os secrets `SIGNING_PFX_BASE64` e `SIGNING_PFX_PASSWORD` no GitHub. O pipeline assina o EXE e os scripts com SHA-256 e timestamp, inclui `SIGNING-REQUIRED` no pacote e o atualizador passa a recusar qualquer assinatura inválida. Sem o certificado, a release continua protegida por hashes internos e atestação de proveniência, mas permanece sem reputação Authenticode/SmartScreen.

### Laboratório físico

O workflow `Physical hardware validation` espera runners self-hosted com os labels `windows` e `hardware-lab`. Cadastre máquinas representando Intel, AMD, notebook, SSD SATA, NVMe e HDD e execute o workflow informando o perfil. O artefato gerado deliberadamente exclui serial, hostname, usuário, IP e IDs do dispositivo.

---

## Testes / Build / Release

```powershell
powershell -ExecutionPolicy Bypass -File .\Tests\Engine.Tests.ps1
powershell -ExecutionPolicy Bypass -File .\Tests\Static.Tests.ps1
powershell -ExecutionPolicy Bypass -File .\Tests\Gui.Layout.Tests.ps1
powershell -ExecutionPolicy Bypass -File .\Tests\Reliability.Tests.ps1
powershell -ExecutionPolicy Bypass -File .\Tests\Updater.Tests.ps1
powershell -ExecutionPolicy Bypass -File .\Compilar-EXE.ps1
```

```bash
git tag v5.9.0
git push origin v5.9.0
# Actions: testes Windows + smoke Bash → ZIP + SHA256SUMS.txt
```

---

## Licença

[MIT](LICENSE)
