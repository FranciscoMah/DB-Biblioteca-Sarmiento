DROP SCHEMA IF EXISTS dbbiblioteca;
CREATE SCHEMA dbbiblioteca;

--
#se crea el esquema dbbiblioteca
--

USE dbbiblioteca;

--
#creacion de la tabla 'usuario'
--

CREATE TABLE usuario (
	id_usuario int NOT NULL AUTO_INCREMENT,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    PRIMARY KEY (id_usuario)
);

--
#creacion de la tabla 'generoliterario'
--

CREATE TABLE generoliterario (
	id_genero int NOT NULL AUTO_INCREMENT,
    tipo_genero VARCHAR(100)not null,
    PRIMARY KEY(id_genero)
);

--
#creacion de la tabla 'autorlibro'
--

CREATE TABLE autorlibro(
	id_autor int NOT NULL AUTO_INCREMENT,
    nombre VARCHAR(100) NOT NULL,
    datedead DATE,
    datenacimiento DATE,
    PRIMARY KEY(id_autor)
);

--
#creacion de la tabla 'editorial'
--

CREATE TABLE editorial (
    id_editorial int NOT NULL AUTO_INCREMENT,
    nombre varchar(100) NOT NULL,
    PRIMARY KEY(id_editorial)
);

--
#creacion de la tabla 'libro'
--

CREATE TABLE libro(
id_libro INT NOT NULL AUTO_INCREMENT,
titulo VARCHAR(100),
date_publicacion DATE,
cantidad_stock int(100),
descripcion VARCHAR(150),
 PRIMARY KEY (id_libro)
);
--
#creacion de la tabla 'libropedido'
--

CREATE TABLE libropedido(
id_alta INT(11) NOT NULL,
id_usuario INT NOT NULL,
id_libro INT NOT NULL,
date_alta DATE NOT NULL,
PRIMARY KEY(id_alta),
FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario),
FOREIGN KEY (id_libro) REFERENCES libro(id_libro)
);

--
#creacion de la tabla 'producido'
--

CREATE TABLE producido(
id_editorial INT NOT NULL,
id_libro INT NOT NULL,
FOREIGN KEY (id_editorial) REFERENCES editorial(id_editorial),
FOREIGN KEY (id_libro) REFERENCES libro(id_libro)
);

--
#creacion de la tabla 'librogenero'
--

CREATE TABLE librogenero(
id_libro INT NOT NULL,
id_genero INT NOT NULL,
FOREIGN KEY (id_libro) REFERENCES libro(id_libro),
FOREIGN KEY (id_genero) REFERENCES generoliterario(id_genero)
);


--
#creacion de la tabla 'escrito'
--

CREATE TABLE escrito(
id_autor INT NOT NULL,
id_libro INT NOT NULL,
FOREIGN KEY (id_autor) REFERENCES autorlibro(id_autor),
FOREIGN KEY (id_libro) REFERENCES libro(id_libro)
);

--
#creacion de la tabla 'editorial_autor'
--

CREATE TABLE editorial_autor(
id_editorial INT NOT NULL,
id_autor INT NOT NULL,
FOREIGN KEY (id_editorial) REFERENCES editorial(id_editorial),
FOREIGN KEY (id_autor) REFERENCES autorlibro(id_autor)
);

--
#creacion de la tabla 'genero_autor'
--

CREATE TABLE genero_autor(
id_genero INT NOT NULL,
id_autor INT NOT NULL,
FOREIGN KEY (id_genero) REFERENCES generoliterario(id_genero),
FOREIGN KEY (id_autor) REFERENCES autorlibro(id_autor)
);

--
#creacion de la tabla 'tabla_auxiliar_libropedido'
#funciona como tabla auditable para guardar los registros de libros prestados luego de que son devueltos
--

CREATE TABLE tabla_auxiliar_libropedido(
id_alta INT PRIMARY KEY,
id_usuario INT,
id_libro INT,
date_modificacion DATE 
);

--
/*Generacion de las vistas para la BD */
--
CREATE OR REPLACE VIEW libro_pedidos_por_usuarios AS
    (SELECT 
        u.nombre AS nombre,
        u.apellido AS apellido,
        l.titulo AS titulo
    FROM libropedido li
        JOIN libro l ON ((li.id_libro = l.id_libro))
        JOIN usuario u ON ((li.id_usuario = u.id_usuario)));
   
CREATE OR REPLACE VIEW autores_y_sus_generos AS
        (SELECT 
			au.nombre as nombreAutor,
            ge.tipo_genero as generoLiterario
		FROM genero_autor gna
			JOIN autorlibro au on au.id_autor = gna.id_autor
            JOIN generoliterario ge on ge.id_genero = gna.id_genero);
            
CREATE OR REPLACE VIEW stock_libros AS
	(SELECT 
		li.id_libro,
		li.titulo,
		au.nombre as nombre_autor,
        li.cantidad_stock as stock
	FROM escrito es
		JOIN libro li on li.id_libro = es.id_libro
        JOIN autorlibro au on au.id_autor = es.id_autor
	WHERE (li.cantidad_stock > 0)); 
    

CREATE OR REPLACE VIEW autores_y_libros AS
    (SELECT 
			au.nombre as nombreAutor,
            li.titulo as titulo_libro
		FROM escrito es
			JOIN autorlibro au on au.id_autor = es.id_autor
            JOIN libro li on li.id_libro = es.id_libro
            ORDER BY nombre ASC); 
        
CREATE OR REPLACE VIEW libro_publicados_por_editoriales AS
	(SELECT 
			li.titulo,
            li.descripcion,
            li.date_publicacion as fecha_publicacion,
            ed.nombre as nombre_editorial
		FROM producido pro
			JOIN libro li on li.id_libro = pro.id_libro
            JOIN editorial ed on ed.id_editorial = pro.id_editorial
            ORDER BY date_publicacion DESC);
            

--
/*Generacion de las funciones para la BD */
--

--
#Funcion: consultar_fecha Esta funcion lo que hace es dar a conocer si la entrega del libro esta vencida o no
--

DELIMITER $$
CREATE FUNCTION consultar_fecha(id_consulta INTEGER) 
RETURNS varchar(50)
READS SQL DATA
    BEGIN   
DECLARE fecha_prestacion int;
DECLARE fecha DATE;
DECLARE fecha1 varchar(50);
set fecha=
(
select date_alta AS fecha
from libropedido
where (id_alta=id_consulta)
);
SET fecha_prestacion=
(
SELECT timestampdiff(MONTH,fecha,current_date()) 
);
set fecha1=
(
IF (fecha_prestacion > 2,'Entrega atrasada','Aun no vence su entrega')
);
        RETURN fecha1;
    END$$
DELIMITER ;

/*

 SELECT consultar_fecha(002) AS "ESTADO DE ENTREGA";

*/

--
#Funcion: eliminar_prestacion Esta funcion lo que hace es eliminar el registro de la prestacion del libro para que no figure mas en la tabla
--

DELIMITER $$
CREATE FUNCTION eliminar_prestacion(id_baja INT) 
RETURNS varchar(20)
DETERMINISTIC
    BEGIN   
        DECLARE id_prestacion int;
 DECLARE estado_prestacion VARCHAR(20);
 SET id_prestacion = 
 (
 SELECT COUNT(*) 
 FROM libropedido 
 WHERE id_alta=id_baja
 );
 IF (id_prestacion > 0) THEN
	SET estado_prestacion = 'libro devuelto';
     	DELETE FROM libropedido WHERE id_alta=id_baja;
    ELSE
    SET estado_prestacion = ('El usuario aun no devuelve el ejemplar');
    END IF;
RETURN estado_prestacion; 
    END$$
DELIMITER ;

/*

 SELECT eliminar_prestacion(002) AS "ESTADO DEL EJEMPLAR";

*/

--
#trigger sumar_stock Este trigger lo que hace es mantener actualizado la columna cantidad_stock a medida que se van prestando los ejemplares
#Para apreciar su accionar hay que ver la tabla libro luego de insertar datos en la tabla libropedido y el stock se ira reduciendo  
--

delimiter $$
CREATE TRIGGER sumar_stock
AFTER INSERT ON libropedido
FOR EACH ROW 
BEGIN
DECLARE idP INT DEFAULT 0;
DECLARE unid INT DEFAULT 0;
SET idP = new.id_libro;
SET unid = new.id_usuario;
UPDATE libro SET cantidad_stock = cantidad_stock - 1 WHERE id_libro = idP; 
END $$

--
#trigger insertar_devoluciones Este trigger lo que hace es insertar en una tabla auxiliar los valores que se van eliminando una vez que los usuarios devuelven los libros para luego ser auditada
#Para apreciar su accionar hay que ver la tabla libro luego de insertar datos en la tabla libropedido y el stock se ira reduciendo  
--

delimiter $$
CREATE TRIGGER insertar_devoluciones
BEFORE DELETE ON libropedido
FOR EACH ROW 
BEGIN
INSERT INTO tabla_auxiliar_libropedido (id_alta, id_usuario, id_libro, date_modificacion) VALUES (OLD.id_alta, OLD.id_usuario, OLD.id_libro, CURRENT_DATE()); 
END $$

/*Generacion de los Store procedures para la BD */

--
#SP: generos_mas_solicitados Este SP lo que hace es dar a conocer un promedio de cuales son los generos mas pedidos
--

DELIMITER //
CREATE PROCEDURE generos_mas_solicitados()
    BEGIN   
        SELECT
		ge.tipo_genero, count(ge.tipo_genero) AS cantidad_genero
    FROM
        libro li
    LEFT JOIN libropedido lp ON (lp.id_libro = li.id_libro)
    INNER JOIN librogenero lg ON (lg.id_libro=li.id_libro)
    INNER JOIN generoliterario ge on (ge.id_genero = lg.id_genero)
	GROUP BY ge.tipo_genero 
    ORDER BY cantidad_genero DESC;
    END
//
DELIMITER ;

/*

 CALL generos_mas_solicitados();

*/

--
#SP: renovar_stock Cuando es llamado este SP lo que hace es mostrar los faltantes de stock(dos o menos libros) y avisar que hay que pedir mas
--

DELIMITER //
CREATE PROCEDURE renovar_stock()
    BEGIN   
        SELECT id_libro, cantidad_stock,
		(
        CASE
		WHEN (cantidad_stock <= 2)
        THEN ('falta stock')
        ELSE ('Hay stock suficiente')
        END
    ) AS estado_stock 
    FROM libro;
    END
//
DELIMITER ;
/*
CALL renovar_stock();
*/

/* Fin de Generacion de Stored Procedures para la base de datos dbbiblioteca */