package com.optativa.thymeleaf.servicio.impl;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Component;

import com.optativa.thymeleaf.entidad.Usuario;
import com.optativa.thymeleaf.repositorio.UsuarioRepositorio;

/** API OFICIAL --> interfaz UserDetailsService
 * https://docs.spring.io/spring-security/reference/api/java/org/springframework/security/core/userdetails/UserDetailsService.html
 */
@Component
public class UserDetailsServiceImpl implements UserDetailsService {

	@Autowired
	private UsuarioRepositorio usuarioRepositorio;
	
	
	@Override
	public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        String username_ = normalizar(username);

		Usuario usuario = usuarioRepositorio.findByNombre(username_);
		
		if(usuario == null) throw new UsernameNotFoundException("Usuario no encontrado");
		
		
		return User.withUsername(username)
				.roles(usuario.getRol().toString())
				.password(usuario.getContrasena())
				.build();
	}
	
	private String normalizar(String username) {
        if (username == null || username.isBlank()) {
            throw new UsernameNotFoundException("Username vacío");
        }
        // Si en tu BBDD guardas tal cual, deja solo trim().
        // Si guardas en minúsculas, usa lowerCase.
        return username.trim().toLowerCase();
    }

}
