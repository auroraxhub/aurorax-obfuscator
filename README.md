# Aurora X Obfuscator

Aurora X Obfuscator es una herramienta para ofuscar scripts Lua con un runtime (VM) embebido. El objetivo de este repositorio es proporcionar un ofuscador de nivel medio que equilibre compatibilidad con protección.

Características (MVP)
- Ofuscador en Python que realiza:
  - Renombrado de identificadores locales y funciones (análisis léxico básico).
  - Extracción y cifrado de literales de cadena (XOR + Base64).
  - Emisión de un paquete ofuscado que contiene el bytecode y un runtime/VM en Lua.
- VM en Lua (vm/aurorax_vm_bytecode.lua) que desempaqueta, decodifica y ejecuta el bytecode.

Compatibilidad
- Diseñado para ser compatible con Lua 5.1+ y LuaJIT.
- Algunos scripts con manipulaciones muy específicas del entorno o módulos nativos pueden requerir ajustes.

Uso rápido (local)

1. Instala Python 3.10+.
2. Clona el repo auroraxhub/aurorax-obfuscator y sitúate en la carpeta del proyecto.
3. Obfusca un script:

   python -m aurorax_obfuscator.cli examples/sample.lua -o examples/sample.obf.lua

4. Ejecuta el resultado con Lua/LuaJIT:

   lua examples/sample.obf.lua

Estructura del repo
- src/aurorax_obfuscator/ - código del ofuscador en Python
- vm/aurorax_vm_bytecode.lua - runtime/VM en Lua
- examples/ - ejemplos de entrada y salida
- LICENSE, README.md

Próximos pasos
- Ampliar el parser/AST para manejo más robusto de alcance (scopes) y módulos.
- Mejorar la VM para soportar más operaciones en forma nativa (bytecode propio completo).
- Añadir tests y CI (GitHub Actions).

Copyright
Copyright (c) 2026 Aurora X
