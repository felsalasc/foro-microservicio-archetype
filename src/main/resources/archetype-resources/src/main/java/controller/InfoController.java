#set( $dollar = '$' )
package ${package}.controller;

import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class InfoController {
    private final String nombre;
    public InfoController(@Value("${dollar}{spring.application.name}") String nombre) { this.nombre = nombre; }
    @GetMapping("/api/info")
    public Map<String, String> info() { return Map.of("aplicacion", nombre, "estado", "UP"); }
}
