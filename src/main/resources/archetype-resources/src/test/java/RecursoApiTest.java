package ${package};

import ${package}.support.UsuariosStub;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties = {
    "spring.datasource.url=jdbc:h2:mem:arquetipo_test;MODE=Oracle;DB_CLOSE_DELAY=-1",
    "spring.datasource.driver-class-name=org.h2.Driver",
    "spring.datasource.username=sa", "spring.datasource.password=",
    "spring.jpa.hibernate.ddl-auto=create-drop", "spring.sql.init.mode=never"
})
@ActiveProfiles("local")
@AutoConfigureMockMvc
class RecursoApiTest {
    private static final UsuariosStub usuarios = crearStub();
    private static UsuariosStub crearStub() {
        try { return new UsuariosStub(); } catch (java.io.IOException e) { throw new ExceptionInInitializerError(e); }
    }
    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("usuarios.base-url", usuarios::baseUrl);
        registry.add("usuarios.connect-timeout", () -> "200ms");
        registry.add("usuarios.read-timeout", () -> "300ms");
    }
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper mapper;
    @BeforeEach void identidadAdmin() {
        usuarios.reset();
        usuarios.respuesta(200, "{\"id\":1,\"nombre\":\"Admin de prueba\",\"correo\":\"admin@example.test\",\"rol\":\"ADMINISTRADOR\"}");
    }
    @AfterAll static void cerrarStub() { usuarios.close(); }
    private String json(String nombre) throws Exception { return mapper.writeValueAsString(java.util.Map.of("nombre", nombre)); }
    private JsonNode crear(String nombre) throws Exception {
        String body = mvc.perform(post("/api/recursos").header("Authorization", "Bearer prueba-admin")
                .contentType(MediaType.APPLICATION_JSON).content(json(nombre)))
                .andExpect(status().isCreated()).andExpect(header().exists("Location"))
                .andReturn().getResponse().getContentAsString();
        return mapper.readTree(body);
    }
    @Test void informacionPublicaNoDependeDeUsuarios() throws Exception {
        mvc.perform(get("/api/info")).andExpect(status().isOk())
            .andExpect(jsonPath("$.aplicacion").value("${artifactId}"))
            .andExpect(jsonPath("$.estado").value("UP"));
        assertThat(usuarios.peticiones.get()).isZero();
    }
    @Test void crudPersisteYConservaIdentificador() throws Exception {
        JsonNode creado = crear("  Recurso de ejemplo  "); long id = creado.get("id").asLong();
        assertThat(creado.get("nombre").asText()).isEqualTo("Recurso de ejemplo");
        assertThat(id).isPositive();
        mvc.perform(get("/api/recursos/" + id).header("Authorization", "Bearer prueba-admin"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.nombre").value("Recurso de ejemplo"));
        mvc.perform(put("/api/recursos/" + id).header("Authorization", "Bearer prueba-admin").contentType(MediaType.APPLICATION_JSON).content(json("Editado")))
            .andExpect(status().isOk()).andExpect(jsonPath("$.id").value(id));
        mvc.perform(get("/api/recursos").header("Authorization", "Bearer prueba-admin"))
            .andExpect(status().isOk()).andExpect(content().string(org.hamcrest.Matchers.containsString("Editado")));
        mvc.perform(delete("/api/recursos/" + id).header("Authorization", "Bearer prueba-admin")).andExpect(status().isNoContent());
        mvc.perform(get("/api/recursos/" + id).header("Authorization", "Bearer prueba-admin"))
            .andExpect(status().isNotFound()).andExpect(content().contentTypeCompatibleWith("application/problem+json"));
    }
    @Test void nombreDeCienCaracteresEsValido() throws Exception { assertThat(crear("a".repeat(100)).get("nombre").asText()).hasSize(100); }
    @ParameterizedTest
    @ValueSource(strings = {"", " ", "a", " a ", "\t\n"})
    void rechazaNombresInvalidosDespuesDeTrim(String nombre) throws Exception {
        mvc.perform(post("/api/recursos").header("Authorization", "Bearer prueba-admin").contentType(MediaType.APPLICATION_JSON).content(json(nombre)))
            .andExpect(status().isBadRequest()).andExpect(content().contentTypeCompatibleWith("application/problem+json"));
    }
    @Test void rechazaNombreLargo() throws Exception {
        mvc.perform(post("/api/recursos").header("Authorization", "Bearer prueba-admin").contentType(MediaType.APPLICATION_JSON).content(json("a".repeat(101))))
            .andExpect(status().isBadRequest());
    }
    @ParameterizedTest
    @ValueSource(strings = {"{}", "{\"nombre\":null}", "{\"nombre\":42}", "{\"nombre\":true}", "{\"nombre\":\"Valido\",\"rol\":\"ADMINISTRADOR\"}", "{\"nombre\":\"Valido\"} {}"})
    void rechazaJsonInvalidoOPropiedadesNoPermitidas(String body) throws Exception {
        mvc.perform(post("/api/recursos").header("Authorization", "Bearer prueba-admin").contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest());
    }
    @ParameterizedTest @ValueSource(longs = {0, -1, 999999})
    void recursoAusenteNoSeModificaNiSeElimina(long id) throws Exception {
        mvc.perform(get("/api/recursos/" + id).header("Authorization", "Bearer prueba-admin")).andExpect(status().isNotFound());
        mvc.perform(put("/api/recursos/" + id).header("Authorization", "Bearer prueba-admin").contentType(MediaType.APPLICATION_JSON).content(json("Actualizado"))).andExpect(status().isNotFound());
        mvc.perform(delete("/api/recursos/" + id).header("Authorization", "Bearer prueba-admin")).andExpect(status().isNotFound());
    }
    @Test void noAceptaAccesoAnonimo() throws Exception {
        mvc.perform(get("/api/recursos")).andExpect(status().isUnauthorized()).andExpect(header().string("WWW-Authenticate", "Bearer"));
        mvc.perform(post("/api/recursos").contentType(MediaType.APPLICATION_JSON).content(json("Privado"))).andExpect(status().isUnauthorized());
    }
    @Test void usuarioLeePeroNoEscribe() throws Exception {
        long id = crear("Lectura de usuario").get("id").asLong();
        usuarios.respuesta(200, UsuariosStub.USUARIO);
        mvc.perform(get("/api/recursos/" + id).header("Authorization", "Bearer prueba-usuario")).andExpect(status().isOk());
        mvc.perform(post("/api/recursos").header("Authorization", "Bearer prueba-usuario").contentType(MediaType.APPLICATION_JSON).content(json("Prohibido"))).andExpect(status().isForbidden());
        mvc.perform(put("/api/recursos/" + id).header("Authorization", "Bearer prueba-usuario").contentType(MediaType.APPLICATION_JSON).content(json("Prohibido"))).andExpect(status().isForbidden());
        mvc.perform(delete("/api/recursos/" + id).header("Authorization", "Bearer prueba-usuario")).andExpect(status().isForbidden());
    }
    @Test void tokenRechazadoNoAccede() throws Exception {
        usuarios.respuesta(401, "{}");
        mvc.perform(get("/api/recursos").header("Authorization", "Bearer vencido")).andExpect(status().isUnauthorized());
    }
    @Test void encabezadoMalformadoNoConsultaIdentidad() throws Exception {
        mvc.perform(get("/api/recursos").header("Authorization", "Bearer token con espacios")).andExpect(status().isUnauthorized());
        assertThat(usuarios.peticiones.get()).isZero();
    }
    @ParameterizedTest @ValueSource(ints = {302, 403, 500, 503})
    void fallaCerradoCuandoIdentidadNoEsVerificable(int status) throws Exception {
        usuarios.respuesta(status, "{}");
        mvc.perform(get("/api/recursos").header("Authorization", "Bearer prueba-admin")).andExpect(status().isServiceUnavailable());
        assertThat(usuarios.redirecciones.get()).isZero();
    }
    @Test void identidadInvalidaNoAccede() throws Exception {
        usuarios.respuesta(200, "{\"id\":1,\"nombre\":\"Admin\",\"correo\":\"admin@example.test\",\"rol\":\"SUPERADMIN\"}");
        mvc.perform(get("/api/recursos").header("Authorization", "Bearer prueba-admin")).andExpect(status().isServiceUnavailable());
    }
    @Test void timeoutDeIdentidadNoAccede() throws Exception {
        usuarios.demora(false);
        mvc.perform(get("/api/recursos").header("Authorization", "Bearer prueba-admin")).andExpect(status().isServiceUnavailable());
    }
}
