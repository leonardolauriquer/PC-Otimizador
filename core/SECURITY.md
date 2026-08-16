# Segurança — PC Otimizador Pro

## Regras globais

1. **Nunca** percorrer por padrão: Documentos, Fotos, Vídeos, Desktop, Downloads ou seus ancestrais.
2. Preferir **dry-run** / estimativa antes de limpeza real.
3. Ações avançadas exigem confirmação explícita.
4. Mobile (Android/iOS): sem limpeza de sistema; só o que o sandbox permite.
5. Logs locais; sem telemetria obrigatória.

## Por plataforma

| OS | Pode limpar | Não pode / não deve |
|----|-------------|---------------------|
| Windows | Temp, Update cache, TRIM, tweaks opcionais | Arquivos pessoais |
| Linux | Itens antigos de `/tmp`/`/var/tmp` pertencentes ao usuário, caches regeneráveis, journal, pkg cache | `$HOME` projetos, dados pessoais, temporários de outros usuários |
| macOS | Itens antigos do temporário do usuário, caches usuário, brew cache, trash | `/tmp` inteiro, SIP system paths, dados pessoais |
| Android (Termux) | `$HOME` Termux, cache do Termux | Armazenamento de outros apps sem root |
| iOS | Quase nada de sistema | Qualquer “otimizador de iPhone” agressivo (rejeitado / inútil) |
