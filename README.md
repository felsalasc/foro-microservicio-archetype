# Arquetipo de microservicios del foro

Plantilla Maven reutilizable para la Sumativa 2 DSY2205.
Coordenadas: **cl.duoc:foro-microservicio-archetype:1.0.0**.

## Qué genera

Un proyecto Spring Boot 3.5.16 / Java 17 con Maven Wrapper 3.9.14, capas
controlador–servicio–repositorio, entidad JPA, DTOs, validaciones y errores
`application/problem+json`. Incluye CRUD de `Recurso`, seguridad Bearer mediante
foro-usuarios, perfiles H2 y Oracle, SQL, pruebas y colección Postman.

La información mínima de arranque se consulta con GET `/api/info` sin token.
GET `/api/recursos` y GET `/api/recursos/{id}` requieren usuario autenticado.
POST, PUT y DELETE requieren ADMINISTRADOR. El recurso contiene id y nombre;
nombre debe tener de 2 a 100 caracteres después de quitar espacios exteriores.

## Instalar y comprobar el arquetipo

PowerShell 5.1 o 7, con JDK 17 o superior y JAVA_HOME configurado. En este equipo
se verificó con el JDK 17 ya disponible:

```powershell
Set-Location 'C:\Users\fasc8\OneDrive\Documentos\DUOC\DESARROLLO DE SOFTWARE III\SEMANA 5\foro-microservicio-archetype'
$env:JAVA_HOME = 'C:\Users\fasc8\OneDrive\Documentos\DUOC\DESARROLLO DE SOFTWARE III\BIBLIOTECA\.tools\jdk17\jdk-17.0.20.1+1'
.\mvnw.cmd install -B
```

`install` ejecuta las pruebas de generación y después instala el JAR y POM en
el repositorio Maven local del usuario, actualizando el catálogo local.
En otro equipo adapta JAVA_HOME a su JDK. Se requiere Internet en la primera
ejecución para descargar Maven y dependencias; posteriormente se puede añadir
`-o` cuando todo esté almacenado.

La integración oficial de Maven genera dos proyectos distintos:

| Caso | Proyecto | Paquete | Puerto |
|---|---|---|---|
| basic | foro-ejemplo | cl.duoc.foroejemplo | 8084 |
| custom | comunidad-recursos | org.ejemplo.comunidad.recursos | 9094 |

Cada generado ejecuta sus pruebas y empaqueta un JAR ejecutable. Los scripts de
verificación comprueban clases, wrapper, SQL, Postman, .gitignore y conservación
de placeholders Spring/Maven. Los proyectos de prueba quedan bajo
`target/test-classes/projects/<caso>/project/<artifactId>`; su `build.log` y
`target/surefire-reports` contienen la evidencia.
Las pruebas fijan el perfil local y la conexión H2 explícitamente: no usan una
configuración Oracle heredada de la terminal.

## Generar otro servicio

Después de instalar, desde la carpeta del arquetipo:

```powershell
.\scripts\Generar-Servicio.ps1 `
  -ArtifactId 'foro-nuevo' `
  -GroupId 'cl.duoc' `
  -Package 'cl.duoc.foronuevo' `
  -Version '0.0.1-SNAPSHOT' `
  -Port 8084 `
  -OutputRoot '..\generados'
```

La salida será `SEMANA 5/generados/foro-nuevo`. El script utiliza el catálogo
Maven local y coordenadas explícitas del arquetipo. Valida nombres, paquete,
versión y puerto; rechaza palabras reservadas y rutas Windows como CON/NUL.
No sobrescribe destinos existentes y rechaza una carpeta de salida que ya
contenga un pom.xml, para evitar añadir módulos a un proyecto ajeno.

Para comprobar los parámetros sin crear archivos ni invocar Maven:

```powershell
.\scripts\Generar-Servicio.ps1 -ArtifactId 'foro-nuevo' -Package 'cl.duoc.foronuevo' -ValidarSolamente
```

El script acepta `-JavaHome` si no tienes JAVA_HOME configurado. La generación
tampoco crea repositorios Git, descarga wallets ni solicita contraseñas.

## Compilar y ejecutar el generado

```powershell
Set-Location '..\generados\foro-nuevo'
.\mvnw.cmd verify
java -jar '.\target\foro-nuevo-0.0.1-SNAPSHOT.jar'
```

Abrir `http://localhost:8084/api/info`. Los puertos de los servicios existentes
8081, 8082 y 8083 no se utilizan por defecto. `PORT` o `--server.port` permiten
otro puerto. Verificar que esté libre antes de iniciar el proceso. Ctrl+C detiene
solo el servicio de esa terminal.

Para usar el CRUD real, debe estar funcionando Usuarios y proporcionar un token
válido. `USUARIOS_BASE_URL` apunta por defecto a `http://localhost:8081`; el
generado nunca emite tokens ni conoce contraseñas de cuentas reales. La colección
Postman incluye 9 solicitudes con resultados esperados, desde información pública
hasta creación/consulta/edición/eliminación del recurso y permisos de usuario.
Los tokens se completan solo en valores locales de Postman.

El perfil local usa H2 en memoria y pierde datos al detenerse. Oracle usa
ORACLE_URL/ORACLE_USERNAME/ORACLE_PASSWORD y ddl-auto=validate. El SQL de ejemplo
solo crea RECURSOS en el esquema conectado; no crea usuarios ni modifica tablas
del foro. El README generado explica su configuración. No es necesario crear un
cuarto esquema Oracle para demostrar la plantilla: la integración Oracle de la
entrega corresponde a los servicios existentes y ya validados.

## Relación con los microservicios existentes

El arquetipo extrae y formaliza convenciones del codigo del foro. Los servicios existian antes de construir esta plantilla. La adopcion actual genera bases nuevas con Maven y migra el dominio versionado mediante scripts/Adoptar-Servicios.ps1; no atribuye generacion historica a Semana 2. Cada servicio incorpora ARQUETIPO.md, propiedades de procedencia en su POM y .arquetipo/origen.json.

| Convención del arquetipo | Usuarios | Contenido | Moderación |
|---|---|---|---|
| REST JSON + DTOs y validación | Usuario/Auth | Tema/Comentario | Decisión/Visibilidad |
| Controlador → servicio → repositorio JPA | Usuarios | Temas y comentarios | Decisiones |
| Java 17 / Spring Boot 3.5.16 | Sí | Sí | Sí |
| H2 local / Oracle por entorno y SQL propio | Sí | Sí | Sí |
| Errores y separación de credenciales | Sí | Sí | Sí |
| Bearer e identidad | Emite y valida identidad | Consulta Usuarios | Consulta Usuarios |

Los adaptadores de seguridad de la plantilla se reutilizan de Moderación;
Usuarios conserva la responsabilidad diferente de emitir tokens. Recurso es
un ejemplo que se sustituye al crear otro dominio; no incorpora baneo ni tablas
compartidas. El patrón por capas y la inyección de dependencias se mantienen.

## Estructura del arquetipo

```text
pom.xml                              Packaging maven-archetype
src/main/resources/META-INF/maven/    Descriptor de parámetros y filesets
src/main/resources/archetype-resources/
  pom.xml                            POM parametrizado del generado
  src/main/java/                     Código con paquete sustituible
  src/main/resources/                Perfiles Spring
  src/test/java/                     Pruebas del servicio generado
  database/                          SQL Oracle de ejemplo
  postman/                           Colección sin tokens
  README.md, mvnw, mvnw.cmd, .mvn/    Documentación y wrapper
src/test/resources/projects/         Integración oficial basic/custom
scripts/Generar-Servicio.ps1          Generación validada para PowerShell
```

En archivos Velocity, `#set( $dollar = '$' )` preserva expresiones Spring/Maven
que deben sobrevivir a la generación, como ORACLE_PASSWORD y
oracle-database.version. El puerto Postman se parametriza para cada generado.
Las reglas de empaquetado incluyen explícitamente .gitignore; no se empaqueta
target, credenciales, claves ni archivos ajenos a los recursos de la plantilla.

## Evidencias sugeridas para el video

1. Mostrar descriptor, parámetros y carpetas de la plantilla.
2. Mostrar `BUILD SUCCESS` de install y resultados de los dos casos generados.
3. Generar un proyecto con nombre y paquete propios y abrir sus capas.
4. Mostrar las pruebas y JAR del generado, arrancarlo y consultar /api/info.
5. Explicar perfil local/Oracle y la relación con los tres servicios del caso.

El endpoint informativo acredita únicamente arranque HTTP, no disponibilidad de
Oracle. Las pruebas automáticas usan H2 y un servidor HTTP de identidad simulado;
no se atribuyen a una conexión Oracle real del ejemplo generado.

Referencias oficiales: [crear arquetipos](https://maven.apache.org/guides/mini/guide-creating-archetypes.html),
[probar arquetipos](https://maven.apache.org/guides/mini/guide-testing-archetypes.html)
y [empaquetar archivos como .gitignore](https://maven.apache.org/archetype/maven-archetype-plugin/faq.html).

## Generar los tres servicios reales conservando su dominio

Requisitos: JDK 17, Git, arquetipo instalado con mvnw.cmd install y los repositorios clonados en la estructura indicada por foro-despliegue. Los tres repositorios fuente deben tener todos sus cambios confirmados. El destino debe ser una carpeta nueva fuera de las fuentes. El proceso no modifica los repositorios ni despliega contenedores.

```powershell
.\scripts\Adoptar-Servicios.ps1 -SourceRoot 'C:\ForoNexo' -OutputRoot 'C:\ForoNexo\SEMANA 5\.verification\adopcion-nueva'
```

Adapta las rutas a tu equipo y, si es necesario, indica -JavaHome. Se generan foro-usuarios, foro-contenido y foro-moderacion mediante el plugin oficial de Maven. Se conservan el POM base y el wrapper; se sustituye el ejemplo Recurso por el dominio importado desde archivos Git permitidos. Usuarios agrega las dependencias JWT de su implementacion. No se copian repositorios Git, target, wallet ni secretos.

La procedencia registra el commit importado y SHA256 por archivo. Las pruebas comparan el inventario fuente de forma independiente, detectan omisiones deliberadas y verifican que se rechacen destinos existentes/anidados y fuentes con cambios pendientes. Para ejecutar la comprobacion completa (crea tres proyectos, no arranca servicios):

```powershell
.\tests\Test-AdoptarServicios.ps1 -SourceRoot 'C:\ForoNexo' -OutputRoot 'C:\ForoNexo\SEMANA 5\.verification\adopcion-prueba'
```

Despues, ejecuta mvnw.cmd verify en cada proyecto generado. La adopcion se verifico con 85 pruebas de Usuarios, 148 de Contenido y 26 de Moderacion, todas aprobadas. Las fuentes Java, recursos, SQL y pruebas de dominio se conservaron por hash. La evidencia del proceso no sustituye la evaluacion del profesor ni afirma que la version inicial de Semana 2 naciera de esta plantilla.
