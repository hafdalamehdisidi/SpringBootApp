package com.optativa.thymeleaf.repositorio;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.optativa.thymeleaf.entidad.Producto;
@Repository
public interface ProductoRepositorio extends JpaRepository<Producto, Integer>{
    //Listado
	Page<Producto> findAll(Pageable pageable);

	//Buscador por nombre
	Page<Producto> findByNombreContainingIgnoreCase(String nombre, Pageable pageable);


}
