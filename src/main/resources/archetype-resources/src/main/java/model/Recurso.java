package ${package}.model;

import jakarta.persistence.*;

@Entity
@Table(name = "RECURSOS")
public class Recurso {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ID", precision = 19, scale = 0)
    private Long id;
    @Column(name = "NOMBRE", nullable = false, length = 100)
    private String nombre;
    protected Recurso() { }
    public Recurso(String nombre) { this.nombre = nombre; }
    public Long getId() { return id; }
    public String getNombre() { return nombre; }
    public void cambiarNombre(String nombre) { this.nombre = nombre; }
}
