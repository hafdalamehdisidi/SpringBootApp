package com.optativa.thymeleaf.entidad;

import com.optativa.thymeleaf.entidad.enumerado.Rol;

import jakarta.persistence.*;

@Entity
public class Usuario {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true)
    private String nombre;

    private String contrasena;

    @Enumerated(EnumType.STRING)
    private Rol rol;

    public Usuario() {} // recomendable (JPA necesita constructor vacío)

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getNombre() { return nombre; }
    public void setNombre(String nombre) { this.nombre = nombre; }

    public String getContrasena() { return contrasena; }
    public void setContrasena(String contrasena) { this.contrasena = contrasena; }

    public Rol getRol() { return rol; }
    public void setRol(Rol rol) { this.rol = rol; }
}

	
	
	
