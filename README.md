# SpringBootApp --- API Security Example (DWES)

Aplicación educativa desarrollada con **Spring Boot + JWT + control de
roles** y un frontend estático en **HTML + Bootstrap + JavaScript**.

------------------------------------------------------------------------

## Arquitectura

SpringBootApp/ ├── docker-compose.yml ├── docs/api/openapi.yaml ├── log/
├── src/ │ ├── Backend/API_SECURITY_EXAMPLE/ │ ├── Frontend/ │ └──
main.sh

------------------------------------------------------------------------

## Puesta en marcha

### Requisitos

-   Docker
-   Docker Compose
-   Puertos libres: 9091, 8081, 8083

### Comandos disponibles

./src/main.sh setup ./src/main.sh fetch-backend ./src/main.sh up
./src/main.sh down ./src/main.sh reset ./src/main.sh info

------------------------------------------------------------------------

## Cambiar de rama automáticamente

Editar en main.sh:

BACKEND_REPO_URL="https://github.com/profeInformatica101/API_SECURITY_EXAMPLE.git"
BACKEND_BRANCH="agregado_cors"
BACKEND_DIR="\$ROOT_DIR/src/Backend/API_SECURITY_EXAMPLE"

Luego ejecutar:

./src/main.sh fetch-backend ./src/main.sh up

------------------------------------------------------------------------

## URLs de acceso

Frontend → http://localhost:8081\
Backend → http://localhost:9091\
Swagger UI → http://localhost:8083\
MySQL → localhost:3306

------------------------------------------------------------------------

## Usuarios demo

USER → alice.johnson@example.com / password123\
ADMIN → bob.smith@example.com / password456

------------------------------------------------------------------------

## Objetivo educativo

-   Seguridad en APIs REST
-   Control de acceso basado en roles
-   Uso de JWT
-   Documentación OpenAPI
-   Automatización con Docker y Bash

------------------------------------------------------------------------

Proyecto educativo para uso académico.
