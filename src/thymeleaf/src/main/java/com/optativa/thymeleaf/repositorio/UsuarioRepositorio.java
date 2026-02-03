package com.optativa.thymeleaf.repositorio;

import org.springframework.data.jpa.repository.JpaRepository;

import com.optativa.thymeleaf.entidad.Usuario;

public interface UsuarioRepositorio extends JpaRepository<Usuario, Integer>{
	Usuario findByNombre(String username);
}
