# Домашнее задание 3. Docker

## Информация о выполнении задания

Задание выполняется **индивидуально**.

## Цель задания

Научиться упаковывать приложения в контейнеры и организовывать их взаимодействие между собой.

## Условия

В рамках данного задания необходимо упаковать два Python-приложения в два Docker-контейнера и сделать так, чтобы первое приложение отвечало на запрос второго приложения по внутренней сети, а второе — отвечало на запросы внешних пользователей.

## Рекомендуемые этапы выполнения

1. Ознакомьтесь повторно с видеодемонстрацией юнита 6 «Запуск приложений в нескольких контейнерах. Docker Compose».

2. Изучите файлы, которые демонстрировались на занятии:

   **`app-full.py`**
   ```python
   from fastapi import FastAPI
   import asyncpg

   app = FastAPI()

   DATABASE_URL = "postgresql://postgres:pass@postgres:5432/postgres"

   @app.get("/")
   async def root():
       databases = await get_databases()
       return {"message": databases}

   async def get_databases():
       conn = await asyncpg.connect(DATABASE_URL)
       try:
           result = await conn.fetch("SELECT datname FROM pg_database")
           return [record['datname'] for record in result]
       finally:
           await conn.close()
    ```

    **`docker-compose.yml`**

    ```yaml
    services:
    web:
        build:
        context: .
        dockerfile: Dockerfile
        ports:
        - "8000:8000"
        networks:
        - mynetwork

    postgres:
        image: "postgres:latest"
        environment:
        - POSTGRES_PASSWORD=pass
        ports:
        - "5432:5432"
        networks:
        - mynetwork

    networks:
    mynetwork:
    ```

    **`Dockerfile`**

    ```dockerfile
    FROM python:3.9-slim
    RUN pip install "fastapi[standard]"
    RUN pip install asyncpg
    COPY ./app-full.py /home/app/
    CMD ["fastapi", "run", "/home/app/app-full.py"]
    ```

3. Создайте два Python-приложения на FastAPI:
    - **Первое** — по GET-запросу возвращает любой JSON-ответ.
    - **Второе** — по GET-запросу делает запрос к первому приложению и возвращает его ответ.
4. Создайте два `Dockerfile`, в которых будут описаны механизмы сборки приложений. Соберите каждое из них в контейнер и проверьте, что они работают.
5. Опишите в файле `docker-compose.yaml` сборку обоих приложений на основе их `Dockerfile`, задайте приложениям имена, разные порты и общую сеть. Пример конфигурации:

    ```yaml
    services:
    app1:
        build: ./app1        # Путь к Dockerfile для 1-го приложения
        ports:
        - "8000:8000"      # Для доступа извне
        environment:
        APP2_HOST: app2
        APP2_PORT: 5000    # Порт, на котором работает app2
        depends_on:
        - app2             # Убедитесь, что app2 запущено перед app1

    app2:
        build: ./app2        # Путь к Dockerfile для 2-го приложения
        expose:
        - "5000"           # Порт в сети Docker, не для доступа извне
        environment:
        DEBUG: "True"
    ```

6. Укажите во втором приложении в качестве источника адрес и порт первого приложения в общей сети.

## Формат сдачи и отправка задания

**Запись скринкаста** (видео с экрана), на котором должно быть показано:

- Содержимое `docker-compose.yaml` и процесс его запуска
- Два запущенных Docker-контейнера
- Коды приложений внутри каждого контейнера
- Ответ приложения на внешний запрос из браузера

## Сроки выполнения задания

Задание рассчитано на **4 часа**.

## Критерии оценивания

| Критерии оценки | Баллы |
| --- | --- |
| Описан файл `docker-compose.yaml`, в нём прописаны оба приложения, разные порты | 3 |
| Два приложения созданы, одно возвращает JSON-данные, второе делает запрос к первому | 2 |
| При помощи Docker Compose оба приложения запускаются | 3 |
| На запрос в браузере возвращается ответ в соответствии с кодом приложений | 2 |

- **Максимальный балл за задание:** 10 баллов
- **Как проверяется:** в течение недели после дедлайна
