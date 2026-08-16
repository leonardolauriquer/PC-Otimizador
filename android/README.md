# Android — PC Otimizador Pro

## Realidade (importante)

No Android **sem root**, um app **não** pode limpar o sistema inteiro como no Windows.  
Cada app só gerencia o próprio armazenamento (sandbox).

Por isso este repositório oferece:

### 1) Termux (prático hoje)

No [Termux](https://termux.dev):

```bash
pkg install git
# clone o repo ou copie a pasta android/
cd android
chmod +x termux-pc-otimizador.sh
./termux-pc-otimizador.sh
```

O que faz:
- limpa caches do **próprio Termux** (`~/.cache`, `apt clean`, pip/npm cache; sem autoremove)
- **não** apaga DCIM / Download / WhatsApp / fotos

### 2) App nativo (futuro)

Um app Kotlin/Jetpack faria:
- mostrar uso de armazenamento
- limpar **cache do próprio app**
- deep-link para telas de limpeza do sistema Android

Não há “CCleaner global” legítimo na Play Store sem ser OEM/root.

## Sem root vs root

| | Sem root | Com root |
|--|----------|----------|
| Limpar outros apps | Não | Possível (arriscado) |
| Play Store | Escopo limitado | Apps root = risco |

Ver também: [`../core/SECURITY.md`](../core/SECURITY.md)
