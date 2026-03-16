CREATE DATABASE taller2_of;
USE  taller2_of;

CREATE TABLE clientes (
	id INT PRIMARY KEY AUTO_INCREMENT,
    total_compras DECIMAL (12,2),
    nombre VARCHAR (100)
);


CREATE TABLE productos (
	id INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(100),
    precio DECIMAL (12,2),
    stock INT
    
);
CREATE TABLE compras(
 
id INT PRIMARY KEY  AUTO_INCREMENT,
cliente_id INT,
total_compra DECIMAL(12,2),
fecha TIMESTAMP,
FOREIGN KEY(cliente_id)  REFERENCES clientes(id)
);

CREATE TABLE detalle_compras(
 
id INT PRIMARY KEY  AUTO_INCREMENT,
compra_id INT,
producto_id INT,
cantidad INT,
subtotal DECIMAL (12,2),
FOREIGN KEY(compra_id) REFERENCES compras(id),
FOREIGN KEY(producto_id) REFERENCES productos(id)

);
CREATE TABLE auditoria_compras(
 
id INT  PRIMARY KEY AUTO_INCREMENT,
compra_id INT,
total_anterior DECIMAL (12,2),
total_nuevo DECIMAL (12,2),
productos_procesados INT,
fecha TIMESTAMP,
FOREIGN KEY(compra_id) REFERENCES compras(id)
);



/* primer precudere calcular_total_Compras */

DELIMITER //

CREATE PROCEDURE calcular_total_compra(
    IN p_compra_id INT,
    INOUT p_total_anterior DECIMAL(12,2),
    OUT p_productos_procesados INT
)

BEGIN

DECLARE done INT DEFAULT 0;
DECLARE v_subtotal DECIMAL(12,2);

DECLARE curDetalle CURSOR FOR
    SELECT subtotal
    FROM detalle_compras
    WHERE compra_id = p_compra_id;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

SET p_productos_procesados = 0;

OPEN curDetalle;

bucle: LOOP

    FETCH curDetalle INTO v_subtotal;

    IF done = 1 THEN
        LEAVE bucle;
    END IF;

    SET p_total_anterior = p_total_anterior + v_subtotal;
    SET p_productos_procesados = p_productos_procesados + 1;

END LOOP;

CLOSE curDetalle;

END //

DELIMITER ;


-- procedure 2 actualizar_inventario 

DELIMITER //

CREATE PROCEDURE actualizar_inventario(
    IN p_compra_id INT,
    OUT p_productos_actualizados INT
)

BEGIN

DECLARE done INT DEFAULT 0;
DECLARE v_producto_id INT;
DECLARE v_cantidad INT;
DECLARE v_stock INT;

DECLARE curProd CURSOR FOR
    SELECT producto_id, cantidad
    FROM detalle_compras
    WHERE compra_id = p_compra_id;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

SET p_productos_actualizados = 0;

OPEN curProd;

bucle: LOOP

    FETCH curProd INTO v_producto_id, v_cantidad;

    IF done = 1 THEN
        LEAVE bucle;
    END IF;

    SELECT stock INTO v_stock
    FROM productos
    WHERE id = v_producto_id;

    IF v_stock < v_cantidad THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock insuficiente';
    END IF;

    UPDATE productos
    SET stock = stock - v_cantidad
    WHERE id = v_producto_id;

    SET p_productos_actualizados = p_productos_actualizados + 1;

END LOOP;

CLOSE curProd;

END //

DELIMITER ;


-- PRIMER TRIGGER  PROCESAR COMPRA 

DELIMITER //

CREATE TRIGGER trg_procesar_compra
AFTER INSERT ON detalle_compras
FOR EACH ROW

BEGIN

DECLARE v_total DECIMAL(12,2) DEFAULT 0;
DECLARE v_productos INT;

CALL calcular_total_compra(
    NEW.compra_id,
    v_total,
    v_productos
);

UPDATE compras
SET total_compra = v_total
WHERE id = NEW.compra_id;

END //

DELIMITER ;

-- 2 TRIGGER  ACTUALIZAR STOCK 
DELIMITER //

CREATE TRIGGER trg_actualizar_stock
AFTER INSERT ON compras
FOR EACH ROW

BEGIN

DECLARE v_total_anterior DECIMAL(12,2) DEFAULT 0;
DECLARE v_productos INT;

CALL actualizar_inventario(
    NEW.id,
    v_productos
);

INSERT INTO auditoria_compras(
    compra_id,
    total_anterior,
    total_nuevo,
    productos_procesados,
    fecha
)
VALUES(
    NEW.id,
    v_total_anterior,
    NEW.total_compra,
    v_productos,
    NOW()
);

END //

DELIMITER ;
-- INSERTO CLIENTES 
INSERT INTO clientes(nombre,total_compras)
VALUES('Juan',0);

-- INSERTO PRODUCTOS 
INSERT INTO productos(nombre,precio,stock)
VALUES
('Laptop',3000,10),
('Mouse',50,20);

-- CREAR COMPRA 
INSERT INTO compras(cliente_id,total_compra,fecha)
VALUES(1,0,NOW());
-- AGREGO PRODUCTOS A LA COMPRA 
INSERT INTO detalle_compras(compra_id,producto_id,cantidad,subtotal)
VALUES
(1,1,1,3000),
(1,2,2,100);


