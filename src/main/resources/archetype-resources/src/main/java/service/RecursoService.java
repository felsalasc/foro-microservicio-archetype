package ${package}.service;

import ${package}.dto.RecursoRequest;
import ${package}.dto.RecursoResponse;
import ${package}.exception.RecursoNoEncontradoException;
import ${package}.model.Recurso;
import ${package}.repository.RecursoRepository;
import java.util.List;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class RecursoService {
    private final RecursoRepository repository;
    public RecursoService(RecursoRepository repository) { this.repository = repository; }
    private Recurso existente(Long id) { return repository.findById(id).orElseThrow(RecursoNoEncontradoException::new); }
    private RecursoResponse respuesta(Recurso recurso) { return new RecursoResponse(recurso.getId(), recurso.getNombre()); }
    public List<RecursoResponse> listar() { return repository.findAll(Sort.by("id")).stream().map(this::respuesta).toList(); }
    public RecursoResponse obtener(Long id) { return respuesta(existente(id)); }
    @Transactional public RecursoResponse crear(RecursoRequest request) { return respuesta(repository.save(new Recurso(request.nombre()))); }
    @Transactional public RecursoResponse actualizar(Long id, RecursoRequest request) { Recurso recurso = existente(id); recurso.cambiarNombre(request.nombre()); return respuesta(recurso); }
    @Transactional public void eliminar(Long id) { repository.delete(existente(id)); }
}
