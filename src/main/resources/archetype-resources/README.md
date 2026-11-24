# ${artifactId}

Servicio generado con `cl.duoc:foro-microservicio-archetype:1.0.0`.
Java 17, Spring Boot 3.5.16, controlador/servicio/repositorio y DTOs separados.

## Compilar y ejecutar (PowerShell)

Con JDK 17 o superior y JAVA_HOME configurado:

```powershell
.\mvnw.cmd verify
java -jar '.\target\${artifactId}-${version}.jar'
```

Escucha en el puerto ${port}. `PORT` permite cambiarlo. `GET /api/info` es
público y solo informa aplicación y estado: no acredita conectividad con Oracle
ni disponibilidad del proveedor de identidad.

## API de ejemplo

| Método | Ruta | Permiso |
|---|---|---|
| GET | /api/info | Público |
| GET | /api/recursos | Usuario autenticado |
| GET | /api/recursos/{id} | Usuario autenticado |
| POST | /api/recursos | Administrador |
| PUT | /api/recursos/{id} | Administrador |
| DELETE | /api/recursos/{id} | Administrador |

POST/PUT reciben `{"nombre":"Recurso de ejemplo"}`. Nombre de 2–100 caracteres
después de quitar espacios exteriores. Creación 201 con Location, modificación
200, eliminación 204; errores 400/401/403/404 y 503 si la identidad no puede
verificarse. Los errores usan application/problem+json.

El Bearer token se obtiene de foro-usuarios, configurado con USUARIOS_BASE_URL
(predeterminado http://localhost:8081). Lecturas autenticadas y escrituras solo
ADMINISTRADOR. No hay claves ni contraseñas de demostración en este servicio.
Las pruebas simulan Usuarios mediante HTTP en un puerto efímero y no requieren
Oracle ni el servicio real. No confundir el token simulado del test con un JWT
válido para la ejecución real.

Importar `postman/Servicio-Generado.postman_collection.json` y completar
localmente base_url (puerto ${port}), admin_token y usuario_token.
No exportar tokens reales junto al código.

## Persistencia

Perfil local predeterminado: H2 en memoria, datos perdidos al detener el proceso.
Oracle requiere un esquema propio, ejecutar manualmente database/01_estructura.sql
en ese esquema y proporcionar variables de entorno:

```powershell
$env:ORACLE_URL = 'jdbc:oracle:thin:@ALIAS?TNS_ADMIN=RUTA_DEL_WALLET'
$env:ORACLE_USERNAME = 'ESQUEMA_PROPIO'
# Introducir ORACLE_PASSWORD localmente; no escribirla en archivos o repositorios.
$taskPassword = Read-Host 'Contrasena del esquema, sin comillas' -AsSecureString
$env:ORACLE_PASSWORD = [System.Net.NetworkCredential]::new('', $taskPassword).Password
try {
    java -jar '.\target\${artifactId}-${version}.jar' --spring.profiles.active=oracle
} finally {
    Remove-Item Env:ORACLE_PASSWORD -ErrorAction SilentlyContinue
    $taskPassword.Dispose()
}
```

El perfil Oracle valida tablas: no crea ni elimina esquemas o tablas.
No ejecutar el SQL en los esquemas del foro existentes para esta demostración.
La disponibilidad de /api/info por sí sola no prueba operaciones con la BD.

## Adaptar el servicio

Sustituir Recurso y su API por el dominio del nuevo servicio, manteniendo las
capas, DTOs, validación, errores y pruebas. Los recursos pertenecen al servicio;
no se comparten entidades o tablas con otros microservicios. No se incluye la
lógica de baneo específica de foro-moderacion.

Los perfiles, SQL y controladores son una base común, no equivalen a desplegar
un cuarto servicio del caso. Docker y despliegue se configuran según el entorno.
