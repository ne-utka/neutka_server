# neutka_server

Репозиторий серверных и клиентских ресурсов проекта neutka.

## Структура

- `shaderpack/neutka/source` — исходники шейдерпака neutka.
- `shaderpack/neutka/dist/neutka.zip` — готовый архив для Iris.
- `shaderpack/neutka/config/iris.properties` — конфигурация Iris с выбранным `neutka.zip`.
- `resourcepack` — место для будущего ресурспака.
- `scripts/Clientizen` — клиентские скрипты Clientizen.
- `scripts/Denizen` — серверные скрипты Denizen.
- `scripts/Citizens` — скрипты и конфигурация Citizens.
- `scripts/Depenizen` — интеграционные скрипты Depenizen.

## Установка шейдерпака

1. Скопировать `shaderpack/neutka/dist/neutka.zip` в папку `shaderpacks` профиля Minecraft.
2. При необходимости скопировать `shaderpack/neutka/config/iris.properties` в папку `config` профиля.
3. Запустить Minecraft с Fabric 26.1.2, Iris и Sodium.

Настройки эффекта Outline находятся в `shaderpack/neutka/source/shaders/settings.glsl`, а структура меню Iris — в `shaderpack/neutka/source/shaders/shaders.properties`.
