# Importação de músicas do Psych Engine

Em builds nativas (Android e desktop), extraia cada mod em `psych-mods/<nome>/`, ao lado da pasta `mods/`. No Android, use a pasta de arquivos do aplicativo. A pasta deve conter `data/<musica>/<musica>.json` e `songs/<musica>/Inst.ogg`. Reinicie o jogo: as músicas compatíveis aparecem no Freeplay.

Exemplo:

```text
psych-mods/meu-mod/
  data/minha-musica/minha-musica.json
  data/minha-musica/minha-musica-hard.json
  songs/minha-musica/Inst.ogg
  songs/minha-musica/Voices.ogg
```

São suportados charts de quatro teclas no formato Psych com seções `mustHitSection`, sustains, velocidades por dificuldade, mudanças de BPM e `sectionBeats`. A importação aceita `Voices.ogg` ou vozes separadas `Voices-Player.ogg` e `Voices-Opponent.ogg`. Os timestamps continuam em milissegundos. A câmera acompanha a posse de cada seção.

Esta é uma camada de compatibilidade de charts e áudio, não compatibilidade completa com mods Psych. Personagens e cenários personalizados, Lua/HScript, shaders e eventos Psych precisam de adaptação para V-Slice. As músicas importadas usam BF, Dad, GF e o cenário padrão. Charts com tipos de nota especiais, seções GF ou animações alternativas são rejeitados e registrados; dificuldades com timelines de BPM diferentes também precisam de adaptação. Eventos Psych não são executados. Consulte `psych-import-report.txt` dentro do mod gerado para os limites e arquivos rejeitados.

O jogo cria `mods/psych-<nome>/` uma única vez, sem modificar os arquivos originais nem sobrescrever mods existentes. Para reimportar uma atualização, remova apenas a pasta gerada correspondente e reinicie. A primeira importação copia o áudio e pode demorar; as seguintes inicializações reutilizam o resultado. Uma importação sem músicas válidas deixa um arquivo `*-import-report.txt` na pasta `mods/`.

# Build Android para jogar

O workflow `Android APK` gera código release sem debugger Flixel, contadores, visualizador de áudio nem pré-carga de todas as bibliotecas. O Android usa limite de 60 FPS, inclusive em telas de 90/120 Hz. As bibliotecas de assets são carregadas conforme necessárias; isso troca uso antecipado de memória por possíveis pausas no primeiro acesso.

A área de jogo permanece em 1280×720 (16:9), com barras em telas de outra proporção. Não há redução dos gráficos originais. O ganho de memória/FPS depende da música, dos assets e do aparelho; ainda exige medição em dispositivo real.

# Teste do importador

Com Haxe 4.3.7, execute `bash scripts/test-psych-importer.sh`. O teste usa diretório temporário e cobre posse das notas, sustains, BPM em seções vazias, seções variáveis, áudio, isolamento de JSON inválido e proteção contra sobrescrita.
