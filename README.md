# SpringBootApp

## API Security Example --- Spring Boot + JWT + Docker

------------------------------------------------------------------------

## 📌 Descripción

**SpringBootApp** es una aplicación educativa orientada a la
demostración de buenas prácticas en el desarrollo de APIs REST seguras
utilizando:

-   Spring Boot
-   Spring Security
-   JSON Web Tokens (JWT)
-   Control de acceso basado en roles (RBAC)
-   OpenAPI / Swagger
-   Docker y Docker Compose

El proyecto está diseñado para entornos formativos (DWES) y permite
trabajar autenticación, autorización, documentación de APIs y despliegue
reproducible.

------------------------------------------------------------------------

## 🏗 Arquitectura del Proyecto

    SpringBootApp/
    │
    ├── docker-compose.yml
    ├── docs/
    │   └── api/openapi.yaml
    ├── log/
    ├── src/
    │   ├── Backend/
    │   │   └── API_SECURITY_EXAMPLE/
    │   ├── Frontend/
    │   └── main.sh

### Componentes

  ------------------------------------------------------------------------
  Componente              Tecnología              Descripción
  ----------------------- ----------------------- ------------------------
  Backend                 Spring Boot             API REST segura con JWT

  Seguridad               Spring Security         Autenticación y
                                                  autorización

  Frontend                HTML + JS + Bootstrap   Cliente estático para
                                                  consumir la API

  Base de datos           MySQL (Docker)          Persistencia

  Documentación           OpenAPI + Swagger UI    Contrato y pruebas

  Orquestación            Docker Compose          Entorno reproducible
  ------------------------------------------------------------------------

------------------------------------------------------------------------

## 🚀 Puesta en Marcha

### Requisitos

-   Linux (recomendado Debian/Ubuntu si se usa `setup`)
-   Docker
-   Docker Compose
-   Puertos disponibles:
    -   9091 → Backend
    -   8081 → Frontend
    -   8083 → Swagger UI

------------------------------------------------------------------------

## ⚙️ Gestión mediante Script

El archivo `main.sh` automatiza la instalación, descarga del backend y
despliegue.

### Comandos disponibles

    ./src/main.sh setup
    ./src/main.sh fetch-backend
    ./src/main.sh up
    ./src/main.sh down
    ./src/main.sh reset
    ./src/main.sh info

### Descripción de comandos

  -----------------------------------------------------------------------
  Comando                        Descripción
  ------------------------------ ----------------------------------------
  setup                          Instala Docker y Compose si no están
                                 presentes

  fetch-backend                  Clona o actualiza el backend según la
                                 rama configurada

  up                             Construye y levanta todos los servicios

  down                           Detiene los contenedores

  reset                          Elimina volúmenes y reconstruye el
                                 entorno

  info                           Muestra versiones y URLs activas
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## 🔄 Gestión de Ramas del Backend

La rama descargada automáticamente se define en `main.sh`:

    BACKEND_REPO_URL="https://github.com/profeInformatica101/API_SECURITY_EXAMPLE.git"
    BACKEND_BRANCH="agregado_cors"
    BACKEND_DIR="$ROOT_DIR/src/Backend/API_SECURITY_EXAMPLE"

Para cambiar la versión del backend:

1.  Modificar `BACKEND_BRANCH`
2.  Ejecutar:

```{=html}
<!-- -->
```
    ./src/main.sh fetch-backend
    ./src/main.sh up

El sistema realizará:

-   git fetch
-   git checkout `<rama>`{=html}
-   git pull
-   Reconstrucción del contenedor

------------------------------------------------------------------------

## 🌍 Endpoints Principales

### Autenticación

POST `/api/v1/auth/signin`

### Libros

GET `/api/v1/libros`\
POST `/api/v1/libros`\
GET `/api/v1/libros/{id}`\
PUT `/api/v1/libros/{id}`\
DELETE `/api/v1/libros/{id}`

### Usuarios (ROLE_ADMIN)

GET `/api/v1/users`

------------------------------------------------------------------------

## 🔐 Modelo de Seguridad

-   Autenticación JWT (Bearer Token)
-   Roles soportados:
    -   ROLE_USER (lectura)
    -   ROLE_ADMIN (CRUD completo)
-   Diferenciación clara entre errores 401 y 403
-   Gestión de expiración de token en frontend

------------------------------------------------------------------------

## 👤 Credenciales de Entorno Educativo

  Rol     Usuario                     Password
  ------- --------------------------- -------------
  USER    alice.johnson@example.com   password123
  ADMIN   bob.smith@example.com       password456

⚠ Uso exclusivo para pruebas académicas.

------------------------------------------------------------------------

## 📘 Documentación API

Contrato oficial:

    docs/api/openapi.yaml

Disponible mediante Swagger UI en:

http://localhost:8083

------------------------------------------------------------------------

## 🧪 Observabilidad

Los logs se almacenan en:

    log/

Para inspección en tiempo real:

    docker compose logs -f

------------------------------------------------------------------------

## 🎯 Objetivos Formativos

-   Comprender autenticación basada en tokens
-   Implementar control de acceso por roles
-   Documentar APIs con OpenAPI
-   Desplegar aplicaciones con Docker
-   Automatizar entornos con Bash

------------------------------------------------------------------------

## 📄 Licencia

Proyecto académico destinado a fines educativos.
