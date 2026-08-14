# Segurança — PC Otimizador Pro

## Regras globais

1. **Nunca** apagar por padrão: Documentos, Fotos, Vídeos, Desktop, Downloads.
2. Preferir **dry-run** / estimativa antes de limpeza real.
3. Ações avançadas exigem confirmação explícita.
4. Mobile (Android/iOS): sem limpeza de sistema; só o que o sandbox permite.
5. Logs locais; sem telemetria obrigatória.

## Por plataforma

| OS | Pode limpar | Não pode / não deve |
|----|-------------|---------------------|
| Windows | Temp, Update cache, TRIM, tweaks opcionais | Arquivos pessoais |
| Linux | /tmp, caches regeneráveis, journal, pkg cache | `$HOME` projetos, dados pessoais |
| macOS | caches usuário, brew cache, trash | SIP system paths, dados pessoais |
| Android (Termux) | `$HOME` Termux, cache do Termux | Armazenamento de outros apps sem root |
| iOS | Quase nada de sistema | Qualquer “otimizador de iPhone” agressivo (rejeitado / inútil) |
