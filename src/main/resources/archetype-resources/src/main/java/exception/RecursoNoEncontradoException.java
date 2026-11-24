package ${package}.exception;

public class RecursoNoEncontradoException extends RuntimeException {
    public RecursoNoEncontradoException() { super("El recurso solicitado no existe"); }
}
