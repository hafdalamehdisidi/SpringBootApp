package com.optativa.thymeleaf.semilla;

import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import com.github.javafaker.Faker;
import com.optativa.thymeleaf.entidad.Producto;
import com.optativa.thymeleaf.entidad.Usuario;
import com.optativa.thymeleaf.entidad.enumerado.Rol;
import com.optativa.thymeleaf.repositorio.UsuarioRepositorio;
import com.optativa.thymeleaf.servicio.ProductoServicio;


@Component
public class IniciarDatos implements CommandLineRunner {

	private final int TOTAL_PRODUCTO = 100;


	private final ProductoServicio servicio;
	private final UsuarioRepositorio usuarioRepositorio;
	 private final PasswordEncoder passwordEncoder;
	
	public IniciarDatos(ProductoServicio servicio, UsuarioRepositorio usuarioRepositorio, PasswordEncoder passwordEncoder)
	{
		this.servicio = servicio;
		this.usuarioRepositorio= usuarioRepositorio;
		this.passwordEncoder = passwordEncoder;
	}
	
	
	
	private void crearUsuarioSiNoExiste(String nombre, String contrasenaEnClaro, Rol rol) {
		// tu repo devuelve null si no existe
		if (usuarioRepositorio.findByNombre(nombre) != null) {
			return;
		}

		Usuario u = new Usuario();
		u.setNombre(nombre);
		u.setContrasena(passwordEncoder.encode(contrasenaEnClaro));
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

	
}
