package com.optativa.thymeleaf.repositorio;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.optativa.thymeleaf.entidad.Producto;
@Repository
public interface ProductoRepositorio extends JpaRepository<Producto, Integer>{

}
