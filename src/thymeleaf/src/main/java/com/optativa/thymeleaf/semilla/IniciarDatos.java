package com.optativa.thymeleaf.semilla;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import com.github.javafaker.Faker;
import com.optativa.thymeleaf.entidad.Producto;
import com.optativa.thymeleaf.entidad.Usuario;
import com.optativa.thymeleaf.entidad.enumerado.Rol;
import com.optativa.thymeleaf.repositorio.UsuarioRepositorio;
import com.optativa.thymeleaf.servicio.ProductoServicio;

import jakarta.annotation.PostConstruct;

@Component
public class IniciarDatos implements CommandLineRunner {

	private final int TOTAL_PRODUCTO = 100;

	@Autowired
	private ProductoServicio servicio;
	@Autowired
	private UsuarioRepositorio usuarioRepositorio;

	private void crearUsuarioSiNoExiste(String nombre, String contrasenaEnClaro, Rol rol) {
		// tu repo devuelve null si no existe
		if (usuarioRepositorio.findByNombre(nombre) != null) {
			return;
		}

		Usuario u = new Usuario();
		u.setNombre(nombre);
		u.setContrasena(passwordEncoder().encode(contrasenaEnClaro));
		u.setRol(rol);

		usuarioRepositorio.save(u);
	}

	@Override
	public void run(String... args) throws Exception {
		for (int i = 0; i < TOTAL_PRODUCTO; i++) {
			Producto p = new Producto();
			p.setCategoria(Faker.instance().dog().name());
			p.setNombre(Faker.instance().artist().name());
			p.setPrecio(Faker.instance().number().randomDouble(2, 10, 100));

			servicio.agregarProducto(p);
		}

		crearUsuarioSiNoExiste("admin", "admin123", Rol.ADMIN);
		crearUsuarioSiNoExiste("manager", "manager123", Rol.MANAGER);
		crearUsuarioSiNoExiste("usuario", "usuario123", Rol.USUARIO);

	}

	@Bean
	PasswordEncoder passwordEncoder() {
		return new BCryptPasswordEncoder();
	}
}
