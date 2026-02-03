package com.optativa.thymeleaf.configuracion;

import org.springframework.boot.security.autoconfigure.web.servlet.PathRequest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.HeadersConfigurer;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;

import com.optativa.thymeleaf.entidad.enumerado.Rol;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Bean  /** Acceso a AuthetnticationManager */
    AuthenticationManager authenticationManager(AuthenticationConfiguration authenticationConfiguration) 
    		throws Exception{
		return authenticationConfiguration.getAuthenticationManager();
	} 
/*
	@Bean //Encriptar contraseñas 
	PasswordEncoder passwordEncoder() {
		return new BCryptPasswordEncoder();
	}*/
	/*
	 @Bean
	UserDetailsService users(PasswordEncoder passwordEncoder) {
	
		UserDetails user1 = User.builder().username("user1")
				.password(passwordEncoder.encode("user1")).roles("USER").build();
		UserDetails admin1 = User.builder().username("admin1")
				.password(passwordEncoder.encode("admin1")).roles("ADMIN").build();
		
		return new InMemoryUserDetailsManager(user1, admin1);
	}
	*/
	   @Bean
	    SecurityFilterChain filterChain(HttpSecurity http) throws Exception {

	        // H2 console necesita iframes
	        http.headers(h -> h.frameOptions(HeadersConfigurer.FrameOptionsConfig::sameOrigin));

	        http.authorizeHttpRequests(auth -> auth
	                // estáticos
	                .requestMatchers(PathRequest.toStaticResources().atCommonLocations()).permitAll()
	                // público
	                .requestMatchers("/", "/saluda").permitAll()
	                // H2 solo ADMIN
	                .requestMatchers(PathRequest.toH2Console()).hasRole(Rol.ADMIN.toString())
	                .requestMatchers("/h2-console/**", "/h2/**").hasRole(Rol.ADMIN.toString())
	                // productos: USER o ADMIN
	                .requestMatchers("/productos/**").hasAnyRole(Rol.USUARIO.toString(), Rol.ADMIN.toString())
	                // el resto: autenticado
	                .anyRequest().authenticated()
	        );
	        // CSRF: desactivar solo para H2
	        http.csrf(csrf -> csrf
	                .ignoringRequestMatchers(PathRequest.toH2Console())
	                .ignoringRequestMatchers("/h2-console/**", "/h2/**")
	        );
	        // login form
	        http.formLogin(form -> form
	                .defaultSuccessUrl("/productos", true)
	                .permitAll()
	        );

	        http.logout(logout -> logout.permitAll());

	        return http.build();
	    }

	
	

}
