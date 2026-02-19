# API Security Example (DWES)

Aplicación educativa desarrollada con **Spring Boot + JWT + Control de
Roles** y un frontend estático en **HTML + Bootstrap + JavaScript**.

Permite demostrar:

-   🔐 Autenticación con JWT
-   👤 Acceso con ROLE_USER
-   👑 Acceso con ROLE_ADMIN
-   📚 CRUD de libros
-   🧾 Documentación OpenAPI
-   🐳 Despliegue con Docker Compose

------------------------------------------------------------------------

## 🏗 Arquitectura

    SpringBootApp/
    │
    ├── docker-compose.yml
    ├── docs/
    │   └── api/openapi.yaml
    ├── log/
    ├── src/
    │   ├── Backend/API_SECURITY_EXAMPLE
    │   ├── Frontend/
    │   └── main.sh

### Componentes

-   **Backend** → Spring Boot (JWT + Spring Security)
-   **Frontend** → HTML + JS (consumo de API REST)
-   **Base de datos** → MySQL (Docker)
-   **Swagger UI** → Documentación interactiva
-   **OpenAPI** → docs/api/openapi.yaml

------------------------------------------------------------------------

## 🚀 Puesta en marcha

### 1️⃣ Requisitos

-   Docker + Docker Compose
-   Puerto 9091 libre (backend)
-   Puerto 8081 libre (frontend)

### 2️⃣ Levantar todo

Desde la raíz del proyecto:

``` bash
./main.sh up-all
```

Servicios esperados:

  Servicio     URL
  ------------ -----------------------
  Backend      http://localhost:9091
  Frontend     http://localhost:8081
  Swagger UI   http://localhost:8083
  MySQL        localhost:3306

------------------------------------------------------------------------

## 🔑 Usuarios demo

  Rol     Email                       Password
  ------- --------------------------- --------------------------
  USER    alice.johnson@example.com   password123
  ADMIN   bob.smith@example.com       password456

⚠ Nota: Las credenciales son **solo para entorno educativo**.

------------------------------------------------------------------------

## 📘 API (OpenAPI)

El contrato oficial de la API se encuentra en:

    docs/api/openapi.yaml

Incluye:

-   Esquemas tipados
-   Respuestas 401 / 403 / 404
-   Modelo de error unificado
-   Paginación Spring Data documentada

Puedes visualizarlo en:

-   Swagger UI (contenedor)
-   https://editor.swagger.io

------------------------------------------------------------------------

## 🔐 Seguridad

-   Autenticación basada en JWT (Bearer Token)
-   Roles soportados:
    -   ROLE_USER
    -   ROLE_ADMIN
-   Manejo automático de token expirado en frontend
-   Logout automático ante 401

------------------------------------------------------------------------

## 📚 Endpoints principales

### Auth

    POST /api/v1/auth/signin

Devuelve un JWT válido.

------------------------------------------------------------------------

### Libros

    GET    /api/v1/libros
    POST   /api/v1/libros
    GET    /api/v1/libros/{id}
    PUT    /api/v1/libros/{id}
    DELETE /api/v1/libros/{id}

-   USER → solo lectura
-   ADMIN → CRUD completo

------------------------------------------------------------------------

### Usuarios (ADMIN)

    GET /api/v1/users

------------------------------------------------------------------------

### Recurso protegido

    GET /api/v1/resources

------------------------------------------------------------------------

## 🧪 Logs

Los logs se almacenan automáticamente en:

    log/

Ejemplo:

``` bash
./main.sh logs
./main.sh logs backend
```

------------------------------------------------------------------------

## 🐳 Docker

Para parar todo:

``` bash
./main.sh down-all
```

Reset completo (borra volumen MySQL):

``` bash
./main.sh reset
```

------------------------------------------------------------------------

## 🎓 Objetivo educativo

Este proyecto está diseñado para:

-   Demostrar control de acceso basado en roles
-   Explicar diferencias entre 401 y 403
-   Practicar consumo de APIs con JWT
-   Enseñar buenas prácticas OpenAPI
-   Integrar frontend simple con backend seguro

------------------------------------------------------------------------

## 📄 Licencia

Proyecto educativo para uso académico.
