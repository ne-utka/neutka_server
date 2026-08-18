# neutka_server

Репозиторий серверных и клиентских ресурсов проекта neutka.

## Структура

- `shaderpack/Shader/source` — исходники шейдерпака Shader.
- `shaderpack/Shader/dist/Shader.zip` — готовый архив для Iris.
- `shaderpack/Shader/config/iris.properties` — конфигурация Iris с выбранным `Shader.zip`.
- `shaderpack/ShaderEffects/source` — отдельный вариант Shader с bloom, цветокоррекцией и виньеткой.
- `shaderpack/ShaderEffects/dist/ShaderEffects.zip` — готовая расширенная сборка для Iris.
- `resourcepack/source` — исходники ресурспака.
- `resourcepack/dist/Resourcepack.zip` — готовый ресурспак для клиента.
- `scripts/Clientizen` — клиентские скрипты Clientizen.
- `scripts/Denizen` — серверные скрипты Denizen.
- `scripts/Citizens` — скрипты и конфигурация Citizens.
- `scripts/Depenizen` — интеграционные скрипты Depenizen.

## Установка шейдерпака

1. Скопировать `shaderpack/Shader/dist/Shader.zip` в папку `shaderpacks` профиля Minecraft.
2. При необходимости скопировать `shaderpack/Shader/config/iris.properties` в папку `config` профиля.
3. Запустить Minecraft с Fabric 26.1.2, Iris и Sodium.

`Shader.zip` и `ShaderEffects.zip` являются самостоятельными вариантами: Iris может использовать только один из них одновременно.

Настройки эффекта Outline находятся в `shaderpack/Shader/source/shaders/settings.glsl`, а структура меню Iris — в `shaderpack/Shader/source/shaders/shaders.properties`.
