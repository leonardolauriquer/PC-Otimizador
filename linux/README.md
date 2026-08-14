# Linux — PC Otimizador Pro

Módulo **separado** do Windows (não é o mesmo `.bat`/PowerShell).

## Requisitos

- Bash 4+
- Linux (Debian/Ubuntu/Fedora/Arch e derivados)
- `sudo` para journal/pacotes/fstrim (opcional, mas recomendado)

## Uso

```bash
cd linux
chmod +x pc-otimizador.sh
./pc-otimizador.sh
```

Presets diretos:

```bash
./pc-otimizador.sh --preset safe --yes
./pc-otimizador.sh --preset safe --dry-run --yes
./pc-otimizador.sh --mode health
./pc-otimizador.sh --mode scan
```

## O que faz (seguro)

| Ação | Detalhe |
|------|---------|
| Temp | `/tmp`, `/var/tmp`, thumbnails |
| Lixeira | `~/.local/share/Trash` |
| Cache usuário | só caches regeneráveis (mesa, browser cache, etc.) |
| Journal | `journalctl --vacuum-time=7d` |
| Pacotes | `apt clean` / `dnf clean` / `pacman -Sc` |
| DNS | `resolvectl flush-caches` |
| Flatpak/Snap | unused / revisões antigas |
| TRIM | `fstrim -av` (SSD) |

## O que **não** faz

- Não apaga `Documents`, `Pictures`, `Downloads`, `Desktop` (whitelist)
- Não formata disco
- Não remove seus projetos em `~/`

Logs: `~/.local/share/pc-otimizador/logs/`
