package ${package}.controller;

import ${package}.dto.RecursoRequest;
import ${package}.dto.RecursoResponse;
import ${package}.service.RecursoService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@RestController
@RequestMapping("/api/recursos")
public class RecursoController {
    private final RecursoService service;
    public RecursoController(RecursoService service) { this.service = service; }
    @GetMapping public List<RecursoResponse> listar() { return service.listar(); }
    @GetMapping("/{id}") public RecursoResponse obtener(@PathVariable Long id) { return service.obtener(id); }
    @PostMapping public ResponseEntity<RecursoResponse> crear(@Valid @RequestBody RecursoRequest request) {
        RecursoResponse response = service.crear(request);
        var location = ServletUriComponentsBuilder.fromCurrentRequest().path("/{id}").buildAndExpand(response.id()).toUri();
        return ResponseEntity.created(location).body(response);
    }
    @PutMapping("/{id}") public RecursoResponse actualizar(@PathVariable Long id, @Valid @RequestBody RecursoRequest request) { return service.actualizar(id, request); }
    @DeleteMapping("/{id}") public ResponseEntity<Void> eliminar(@PathVariable Long id) { service.eliminar(id); return ResponseEntity.noContent().build(); }
}
