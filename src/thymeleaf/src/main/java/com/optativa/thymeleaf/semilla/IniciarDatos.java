package com.optativa.thymeleaf.semilla;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.stereotype.Component;

import com.github.javafaker.Faker;
import com.optativa.thymeleaf.entidad.Producto;
import com.optativa.thymeleaf.servicio.ProductoServicio;

import jakarta.annotation.PostConstruct;

@Component
public class IniciarDatos {
	
	private final int TOTAL_PRODUCTO = 100;

	@Autowired
	private ProductoServicio servicio;
	
	
	@PostConstruct
	void init() {
		
		for(int i=0; i<TOTAL_PRODUCTO; i++) {
		Producto p = new Producto();
		p.setCategoria(fake().dog().name());
		p.setNombre(fake().artist().name());
		p.setPrecio(fake().number().randomDouble(2, 10, 100));
		
		
		servicio.agregarProducto(p);
		}
	}
	
	@Bean
	public Faker fake() {
		return new Faker();
	}
}
