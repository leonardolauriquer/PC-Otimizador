# iOS — PC Otimizador Pro

## Resposta direta

**Não é possível** (de forma legítima) fazer um “otimizador completo de iPhone” como no Windows.

A App Store e o sandbox do iOS **impedem** apps de:
- limpar cache de outros apps
- apagar arquivos do sistema
- alterar DNS/rede global como ferramenta de limpeza
- rodar scripts em background com privilégio

## O que *dá* para fazer (honesto)

1. **Dicas nativas (usuário)**  
   - Ajustes → Geral → Armazenamento do iPhone → recomendações  
   - Apagar apps / fotos / WhatsApp media manualmente  
   - Descarregar apps não usados  

2. **App próprio (se um dia existir)**  
   - Limpar apenas dados/cache **do próprio app**  
   - Mostrar dicas e links para telas do sistema (`UIApplicationOpenSettingsURLString`)  
   - Nunca prometer “liberar 5 GB do iOS” automaticamente  

3. **Perfil de configuração / MDM** (empresas)  
   Fora do escopo deste projeto open-source doméstico.

## Arquivo neste repo

Não há `.ipa` nem script de limpeza de sistema — de propósito.  
Qualquer app que diga “limpa o iPhone inteiro” sem ser a Apple é, no mínimo, enganoso.

Ver também: [`../core/SECURITY.md`](../core/SECURITY.md)
